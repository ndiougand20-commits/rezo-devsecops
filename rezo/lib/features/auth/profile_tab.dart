part of 'auth_flow.dart';

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  bool _loading = false;
  bool _saving = false;
  String? _error;

  List<Map<String, dynamic>> _packs = const [];
  List<Map<String, dynamic>> _messages = const [];
  List<Map<String, dynamic>> _offers = const [];
  List<Map<String, dynamic>> _mediaFiles = const [];
  Map<String, dynamic>? _ownSchool;
  Map<String, dynamic>? _ownCompany;
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;
      unawaited(_loadProfileData());
    }
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final appState = AppScope.of(context);
      await appState.refreshCurrentUser();
      final results = await Future.wait([
        appState.fetchPacks(),
        appState.fetchMessages(),
        appState.fetchOffers(),
        appState.fetchMyMedia(),
      ]);

      if (!mounted) return;
      setState(() {
        _packs = results[0];
        _messages = results[1];
        _offers = results[2];
        _mediaFiles = results[3];
      });

      // Chargement conditionnel de la fiche école / entreprise selon le rôle
      final role = parseUserRole(
          (appState.currentUser?['role'] as String?));
      final myId = appState.currentUser?['id']?.toString();
      if (myId != null) {
        try {
          if (role == UserRole.ecole) {
            final schools = await appState.listSchools();
            if (!mounted) return;
            setState(() {
              _ownSchool = schools.firstWhere(
                (s) => s['ownerUserId']?.toString() == myId,
                orElse: () => <String, dynamic>{},
              );
              if (_ownSchool!.isEmpty) _ownSchool = null;
            });
          } else if (role == UserRole.entreprise) {
            final companies = await appState.listCompanies();
            if (!mounted) return;
            setState(() {
              _ownCompany = companies.firstWhere(
                (c) => c['ownerUserId']?.toString() == myId,
                orElse: () => <String, dynamic>{},
              );
              if (_ownCompany!.isEmpty) _ownCompany = null;
            });
          }
        } catch (_) {
          // Échec silencieux : la section affichera l'option de création.
        }
      }
    } on AuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
      if (error.statusCode == 401) {
        _showSnack('Session expirée, reconnecte-toi');
        await widget.onLogout();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger le profil');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openEditProfile() async {
    final appState = AppScope.of(context);
    final user = Map<String, dynamic>.from(appState.currentUser ?? const {});
    final updated = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditProfileSheet(initialUser: user),
    );

    if (updated == null || updated.isEmpty) {
      return;
    }

    setState(() => _saving = true);
    try {
      await appState.updateProfile(updated);
      await _loadProfileData();
      _showSnack('Profil mis à jour');
    } on AuthException catch (error) {
      _showSnack(error.message);
      if (error.statusCode == 401) {
        await widget.onLogout();
      }
    } catch (_) {
      _showSnack('Erreur lors de la sauvegarde du profil');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _openPackSelector() async {
    if (_packs.isEmpty) {
      _showSnack('Aucun pack disponible pour le moment');
      return;
    }

    final appState = AppScope.of(context);
    final userRole =
        (appState.currentUser?['role']?.toString() ?? '').toUpperCase();
    final filtered = _packs.where((pack) {
      final cible = pack['cible'];
      if (cible == null) return true;
      if (cible is List) {
        if (cible.isEmpty) return true;
        return cible.any((c) => c.toString().toUpperCase() == userRole);
      }
      final s = cible.toString().toUpperCase();
      if (s.isEmpty || s == 'ALL' || s == 'TOUS') return true;
      return s.contains(userRole);
    }).toList();

    final selectedPackId = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choisir un pack',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('Aucun pack disponible pour ton profil')),
              )
            else
              ...filtered.map((pack) {
                final id = pack['id']?.toString() ?? pack['packId']?.toString();
                if (id == null) {
                  return const SizedBox.shrink();
                }
                final prix = pack['prix'];
                final priceLabel = prix == null
                    ? 'Gratuit'
                    : '${prix.toString()} FCFA / mois';
                return Card(
                  child: ListTile(
                    title: Text(
                      pack['nom']?.toString() ??
                          pack['name']?.toString() ??
                          'Pack',
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(priceLabel,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700)),
                        if ((pack['description']?.toString() ?? '')
                            .isNotEmpty)
                          Text(pack['description'].toString()),
                      ],
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(id),
                  ),
                );
              }),
          ],
        );
      },
    );

    if (selectedPackId == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      await AppScope.of(context).changePack(selectedPackId);
      await _loadProfileData();
      _showSnack('Pack mis à jour');
    } on AuthException catch (error) {
      _showSnack(error.message);
      if (error.statusCode == 401) {
        await widget.onLogout();
      }
    } catch (_) {
      _showSnack('Impossible de changer le pack');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'],
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    final file = picked.files.single;
    final bytes = file.bytes;
    final fileName = file.name;
    final maxSize = 8 * 1024 * 1024;

    if (bytes == null || bytes.isEmpty) {
      _showSnack('Impossible de lire le fichier image');
      return;
    }
    if (!_isSupportedImage(fileName)) {
      _showSnack('Format image non supporté (jpeg, png, webp, gif)');
      return;
    }
    if (bytes.length > maxSize) {
      _showSnack('L\'image dépasse la taille maximale autorisée (8MB)');
      return;
    }

    setState(() => _saving = true);
    try {
      final appState = AppScope.of(context);
      final media = await appState.uploadProfilePhoto(
        bytes: bytes,
        fileName: fileName,
      );
      final avatarUrl = media['fileUrl']?.toString();
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
        await appState.updateProfile({'avatarUrl': avatarUrl});
      }
      await _loadProfileData();
      _showSnack('Photo de profil mise à jour');
    } on AuthException catch (error) {
      _showSnack(error.message);
      if (error.statusCode == 401) {
        await widget.onLogout();
      }
    } catch (_) {
      _showSnack('Erreur lors de l\'upload de la photo');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _uploadCategoryPdf({
    required String category,
    required String successLabel,
    bool multiUpload = false,
    bool replaceExisting = false,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      allowMultiple: multiUpload,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }
    if (!mounted) {
      return;
    }

    final maxSize = 12 * 1024 * 1024;
    final files = picked.files;
    for (final file in files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        _showSnack('Impossible de lire le fichier PDF');
        return;
      }
      if (!_isPdf(file.name)) {
        _showSnack('Seuls les fichiers PDF sont autorisés');
        return;
      }
      if (bytes.length > maxSize) {
        _showSnack('Le PDF dépasse la taille maximale autorisée (12MB)');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final appState = AppScope.of(context);
      if (replaceExisting) {
        final existing = _mediaFiles
            .where((entry) =>
                entry['category']?.toString().toUpperCase() == category)
            .toList();
        for (final media in existing) {
          final id = media['id']?.toString();
          if (id != null && id.isNotEmpty) {
            await appState.deleteMyMedia(id);
          }
        }
      }

      for (final file in files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        await appState.uploadJustificatifPdf(
          bytes: bytes,
          fileName: file.name,
          category: category,
        );
      }

      await _loadProfileData();
      _showSnack(successLabel);
    } on AuthException catch (error) {
      _showSnack(error.message);
      if (error.statusCode == 401) {
        await widget.onLogout();
      }
    } catch (_) {
      _showSnack('Erreur lors de l\'upload');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteMedia(String mediaId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce justificatif ?'),
          content: const Text('Cette action est irréversible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _saving = true);
    try {
      await AppScope.of(context).deleteMyMedia(mediaId);
      await _loadProfileData();
      _showSnack('Justificatif supprimé');
    } on AuthException catch (error) {
      _showSnack(error.message);
      if (error.statusCode == 401) {
        await widget.onLogout();
      }
    } catch (_) {
      _showSnack('Suppression impossible');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  bool _isSupportedImage(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  bool _isPdf(String fileName) => fileName.toLowerCase().endsWith('.pdf');

  List<Map<String, dynamic>> _mediaForCategory(String category) {
    return _mediaFiles
        .where((entry) =>
            entry['category']?.toString().toUpperCase() == category)
        .toList()
      ..sort((a, b) {
        final left = a['createdAt']?.toString() ?? '';
        final right = b['createdAt']?.toString() ?? '';
        return right.compareTo(left);
      });
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return value.isNotEmpty ? value[0].toUpperCase() : '?';
  }

  String _toAbsoluteMediaUrl(String? fileUrl) {
    final raw = fileUrl?.trim() ?? '';
    if (raw.isEmpty) {
      return '';
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return '${HttpAuthService.defaultBaseUrl}$raw';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.currentUser ?? const <String, dynamic>{};
    final profile = resolveUserProfile(user);

    final fullName = [
      user['prenom'],
      user['nom'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');

    final role = parseUserRole(user['role'] as String?);
    final packName = user['packNom']?.toString() ?? 'FREE';
    final avatarUrl = _toAbsoluteMediaUrl(user['avatarUrl']?.toString());
    final packFeatures =
        (user['packFeatures'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        const <String>[];
    final headlineChips = _headlineItemsForRole(role, profile);
    final objectiveText = _objectiveForRole(role, profile);
    final showHeadlineSection =
      headlineChips.isNotEmpty || objectiveText.trim().isNotEmpty;
    final showPreferencesSection = role == UserRole.etudiant;
    final canManageOffers = user['canManageOffers'] == true;
    final userId = user['id']?.toString();
    final ownedOffers = canManageOffers && userId != null
        ? _offers
              .where(
                (offer) =>
                    offer['ownerUserId']?.toString() == userId ||
                    offer['userId']?.toString() == userId,
              )
              .toList()
        : const <Map<String, dynamic>>[];

    return RefreshIndicator(
      onRefresh: _loadProfileData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            _InfoBanner(
              message: _error!,
              color: Colors.red.shade50,
              textColor: Colors.red.shade800,
            ),
            const SizedBox(height: 12),
          ],
          _ProfileHeaderCard(
            avatarUrl: avatarUrl,
            fullName: fullName.isEmpty ? 'Mon profil' : fullName,
            email: user['email']?.toString() ?? 'Aucune adresse email',
            roleLabel: role.label,
            packName: packName,
            initials: _initials(fullName.isEmpty
                ? (user['email']?.toString() ?? '?')
                : fullName),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _openEditProfile,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier le profil'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _openPackSelector,
                  icon: const Icon(Icons.workspace_premium_rounded),
                  label: const Text('Changer de pack'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showHeadlineSection) ...[
            _ProfileSectionCard(
              title: role == UserRole.lyceen
                  ? 'Centres d’intérêt et projet'
                  : 'Compétences et objectifs',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ChipWrap(
                    items: headlineChips,
                    emptyLabel: role == UserRole.lyceen
                        ? 'Aucun centre d’intérêt renseigné'
                        : 'Aucune compétence renseignée',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    objectiveText.isNotEmpty
                        ? objectiveText
                        : 'Aucun objectif défini',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (showPreferencesSection) ...[
            _ProfileSectionCard(
              title: 'Préférences',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Secteurs'),
                  const SizedBox(height: 6),
                  _ChipWrap(
                    items: _asStringList(profile['preferencesSecteur']),
                    emptyLabel: 'Aucune préférence secteur',
                  ),
                  const SizedBox(height: 10),
                  const Text('Lieux'),
                  const SizedBox(height: 6),
                  _ChipWrap(
                    items: _asStringList(profile['preferencesLieu']),
                    emptyLabel: 'Aucune préférence lieu',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _ProfileSectionCard(
            title: 'Pack actuel',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  packName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                if ((user['packCible']?.toString() ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Cible : ${user['packCible']}',
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                _ChipWrap(
                  items: packFeatures,
                  emptyLabel: 'Aucune feature déclarée',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (role == UserRole.etudiant) ...[
            _buildDocSection(
              title: 'CV',
              category: 'CV',
              multiUpload: false,
              role: role,
            ),
            const SizedBox(height: 12),
            _buildDocSection(
              title: 'Lettre de motivation',
              category: 'LM',
              multiUpload: false,
              role: role,
            ),
            const SizedBox(height: 12),
            _buildDocSection(
              title: 'Justificatifs de diplômes',
              category: 'DIPLOME',
              multiUpload: true,
              role: role,
            ),
          ],
          if (role == UserRole.lyceen) ...[
            _buildDocSection(
              title: 'Bulletins scolaires',
              category: 'BULLETIN',
              multiUpload: true,
              role: role,
            ),
            const SizedBox(height: 12),
            _buildDocSection(
              title: 'Justificatifs divers',
              category: 'JUSTIFICATIF_RECONN',
              multiUpload: true,
              role: role,
            ),
          ],
          if (role == UserRole.ecole) ...[
            _buildDocSection(
              title: 'Justificatifs de reconnaissance',
              category: 'JUSTIFICATIF_RECONN',
              multiUpload: true,
              role: role,
            ),
            const SizedBox(height: 12),
            _buildDocSection(
              title: 'Photo de l\'établissement',
              category: 'PHOTO',
              multiUpload: false,
              role: role,
            ),
          ],
          if (role == UserRole.entreprise) ...[
            _buildDocSection(
              title: 'Justificatifs d\'entreprise',
              category: 'JUSTIFICATIF_ENTREPRISE',
              multiUpload: true,
              role: role,
            ),
            const SizedBox(height: 12),
            _buildDocSection(
              title: 'Photo / logo entreprise',
              category: 'PHOTO',
              multiUpload: false,
              role: role,
            ),
          ],
          const SizedBox(height: 12),
          _ProfileSectionCard(
            title: 'Historique messages',
            child: _SimpleHistoryList(
              entries: _messages,
              titleKey: 'content',
              fallbackTitle: 'Message',
              subtitleBuilder: (entry) =>
                  entry['createdAt']?.toString() ?? 'Date inconnue',
              emptyLabel: 'Aucun message récent',
            ),
          ),
          if (canManageOffers) ...[
            const SizedBox(height: 12),
            _ProfileSectionCard(
              title: 'Historique offres publiées',
              child: _SimpleHistoryList(
                entries: ownedOffers,
                titleKey: 'titre',
                fallbackTitle: 'Offre',
                subtitleBuilder: (entry) =>
                    entry['datePublication']?.toString() ??
                    entry['createdAt']?.toString() ??
                    'Date inconnue',
                emptyLabel: 'Aucune offre publiée',
              ),
            ),
          ],
          if (role == UserRole.ecole) ...[
            const SizedBox(height: 12),
            _buildSchoolSection(),
          ],
          if (role == UserRole.entreprise) ...[
            const SizedBox(height: 12),
            _buildCompanySection(),
          ],
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    await widget.onLogout();
                  },
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolSection() {
    final school = _ownSchool;
    if (school == null) {
      return _ProfileSectionCard(
        title: 'Ma fiche école',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aucune fiche école pour le moment. Crée-la pour apparaître dans les recommandations des lycéens.',
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : () => _openSchoolSheet(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer ma fiche école'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    final domaines = (school['domaines'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    return _ProfileSectionCard(
      title: 'Ma fiche école',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            school['nomEtablissement']?.toString() ?? 'École',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          if ((school['statut']?.toString() ?? '').isNotEmpty)
            Text('Statut : ${school['statut']}'),
          if ((school['siteWeb']?.toString() ?? '').isNotEmpty)
            Text('Site : ${school['siteWeb']}'),
          if ((school['adresse']?.toString() ?? '').isNotEmpty)
            Text('Adresse : ${school['adresse']}'),
          const SizedBox(height: 8),
          _ChipWrap(items: domaines, emptyLabel: 'Aucun domaine'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _openSchoolSheet(school),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Widget _buildDocSection({
    required String title,
    required String category,
    required bool multiUpload,
    required UserRole role,
  }) {
    final entries = _mediaForCategory(category);
    final isPhoto = category == 'PHOTO';
    final replaceExisting = !multiUpload;
    return _ProfileSectionCard(
      title: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _saving
                      ? null
                      : () {
                          if (isPhoto) {
                            _uploadProfilePhoto();
                          } else {
                            _uploadCategoryPdf(
                              category: category,
                              successLabel: '$title ajouté',
                              multiUpload: multiUpload,
                              replaceExisting: replaceExisting,
                            );
                          }
                        },
                  icon: Icon(
                    isPhoto
                        ? Icons.add_a_photo_rounded
                        : Icons.picture_as_pdf_rounded,
                  ),
                  label: Text(
                    isPhoto
                        ? 'Ajouter une photo'
                        : (multiUpload ? 'Ajouter des PDFs' : 'Ajouter un PDF'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            Text(
              'Aucun document ajouté',
              style: TextStyle(color: Colors.grey.shade700),
            )
          else
            Column(
              children: entries.map((media) {
                final mediaId = media['id']?.toString();
                final fileName = media['originalFileName']?.toString() ??
                    (isPhoto ? 'Photo' : 'Document');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    isPhoto
                        ? Icons.image_outlined
                        : Icons.description_rounded,
                  ),
                  title: Text(fileName),
                  subtitle:
                      Text(media['createdAt']?.toString() ?? 'Date inconnue'),
                  trailing: mediaId == null
                      ? null
                      : IconButton(
                          onPressed: _saving ? null : () => _deleteMedia(mediaId),
                          icon: const Icon(Icons.delete_outline_rounded),
                        ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildCompanySection() {
    final company = _ownCompany;
    if (company == null) {
      return _ProfileSectionCard(
        title: 'Ma fiche entreprise',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aucune fiche entreprise pour le moment. Crée-la pour publier des offres et matcher avec des candidats.',
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _saving ? null : () => _openCompanySheet(null),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Créer ma fiche entreprise'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    return _ProfileSectionCard(
      title: 'Ma fiche entreprise',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            company['raisonSociale']?.toString() ?? 'Entreprise',
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          if ((company['secteurActivite']?.toString() ?? '').isNotEmpty)
            Text('Secteur : ${company['secteurActivite']}'),
          if ((company['taille']?.toString() ?? '').isNotEmpty)
            Text('Taille : ${company['taille']}'),
          if ((company['siteWeb']?.toString() ?? '').isNotEmpty)
            Text('Site : ${company['siteWeb']}'),
          if ((company['adresse']?.toString() ?? '').isNotEmpty)
            Text('Adresse : ${company['adresse']}'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _saving ? null : () => _openCompanySheet(company),
            icon: const Icon(Icons.edit_rounded),
            label: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSchoolSheet(Map<String, dynamic>? existing) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SchoolFormSheet(initial: existing),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final appState = AppScope.of(context);
      if (existing == null) {
        await appState.createSchool(result);
        _showSnack('Fiche école créée');
      } else {
        final id = existing['id']?.toString();
        if (id == null) throw const FormatException('Identifiant école manquant');
        await appState.updateSchool(id, result);
        _showSnack('Fiche école mise à jour');
      }
      await _loadProfileData();
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Sauvegarde impossible');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openCompanySheet(Map<String, dynamic>? existing) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CompanyFormSheet(initial: existing),
    );
    if (result == null) return;
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      final appState = AppScope.of(context);
      if (existing == null) {
        await appState.createCompany(result);
        _showSnack('Fiche entreprise créée');
      } else {
        final id = existing['id']?.toString();
        if (id == null) throw const FormatException('Identifiant entreprise manquant');
        await appState.updateCompany(id, result);
        _showSnack('Fiche entreprise mise à jour');
      }
      await _loadProfileData();
    } on AuthException catch (e) {
      _showSnack(e.message);
    } catch (_) {
      _showSnack('Sauvegarde impossible');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _asStringList(dynamic raw) {
    if (raw is List) {
      return raw
          .map((entry) => entry.toString().trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const [];
      if (!trimmed.contains(',')) return [trimmed];
      return trimmed
          .split(',')
          .map((entry) => entry.trim())
          .where((entry) => entry.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<String> _headlineItemsForRole(
    UserRole role,
    Map<String, dynamic> profile,
  ) {
    switch (role) {
      case UserRole.lyceen:
        return _asStringList(profile['centresInteret']);
      case UserRole.entreprise:
        return _asStringList(profile['besoinsRecrutement']);
      case UserRole.ecole:
        return _asStringList(profile['filieres']);
      case UserRole.etudiant:
        return _asStringList(profile['competences']);
    }
  }

  String _objectiveForRole(UserRole role, Map<String, dynamic> profile) {
    switch (role) {
      case UserRole.lyceen:
        return profile['objectifPostbac']?.toString().trim() ?? '';
      case UserRole.entreprise:
        return profile['descriptionEntreprise']?.toString().trim() ?? '';
      case UserRole.ecole:
        return profile['descriptionEcole']?.toString().trim() ??
            profile['description']?.toString().trim() ??
            '';
      case UserRole.etudiant:
        return profile['objectif']?.toString().trim() ?? '';
    }
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.avatarUrl,
    required this.fullName,
    required this.email,
    required this.roleLabel,
    required this.packName,
    required this.initials,
  });

  final String? avatarUrl;
  final String fullName;
  final String email;
  final String roleLabel;
  final String packName;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 60,
              height: 60,
              child: hasAvatar
                  ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _avatarFallback(context),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return _avatarFallback(context);
                      },
                    )
                  : _avatarFallback(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 2),
                Text(email),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TagPill(label: roleLabel),
                    _TagPill(label: 'Pack $packName'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(BuildContext context) {
    return Container(
      color: Colors.white,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          fontSize: 22,
        ),
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items, required this.emptyLabel});

  final List<String> items;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Text(emptyLabel, style: TextStyle(color: Colors.grey.shade700));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => _TagPill(label: item)).toList(),
    );
  }
}

class _SimpleHistoryList extends StatelessWidget {
  const _SimpleHistoryList({
    required this.entries,
    required this.titleKey,
    required this.fallbackTitle,
    required this.subtitleBuilder,
    required this.emptyLabel,
  });

  final List<Map<String, dynamic>> entries;
  final String titleKey;
  final String fallbackTitle;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(emptyLabel, style: TextStyle(color: Colors.grey.shade700));
    }

    return Column(
      children: entries.take(5).map((entry) {
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.history_rounded),
          title: Text(entry[titleKey]?.toString() ?? fallbackTitle),
          subtitle: Text(subtitleBuilder(entry)),
        );
      }).toList(),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.initialUser});

  final Map<String, dynamic> initialUser;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _prenomController;
  late final TextEditingController _nomController;
  late final TextEditingController _emailController;
  late final TextEditingController _telephoneController;
  late final TextEditingController _avatarController;
  late final TextEditingController _niveauController;
  late final TextEditingController _domaineController;
  late final TextEditingController _competencesController;
  late final TextEditingController _objectifController;
  late final TextEditingController _experiencesController;
  late final TextEditingController _preferencesSecteurController;
  late final TextEditingController _preferencesLieuController;
  late final TextEditingController _raisonSocialeController;
  late final TextEditingController _secteurActiviteController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _siteWebController;
  late final TextEditingController _nomEtablissementController;

  String _taille = 'PME';
  String _statut = 'PRIVE';

  @override
  void initState() {
    super.initState();
    final profile = resolveUserProfile(widget.initialUser);

    _prenomController = TextEditingController(
      text: widget.initialUser['prenom']?.toString() ?? '',
    );
    _nomController = TextEditingController(
      text: widget.initialUser['nom']?.toString() ?? '',
    );
    _emailController = TextEditingController(
      text: widget.initialUser['email']?.toString() ?? '',
    );
    _telephoneController = TextEditingController(
      text: widget.initialUser['telephone']?.toString() ?? '',
    );
    _avatarController = TextEditingController(
      text: widget.initialUser['avatarUrl']?.toString() ?? '',
    );

    _niveauController = TextEditingController(
      text: profile['niveauEtude']?.toString() ?? '',
    );
    _domaineController = TextEditingController(
      text: profile['domaine']?.toString() ?? '',
    );
    _competencesController = TextEditingController(
      text: (profile['competences'] as List?)?.join(', ') ?? '',
    );
    _objectifController = TextEditingController(
      text: profile['objectif']?.toString() ?? '',
    );
    _experiencesController = TextEditingController(
      text: (profile['experiences'] as List?)?.join(', ') ?? '',
    );
    _preferencesSecteurController = TextEditingController(
      text: (profile['preferencesSecteur'] as List?)?.join(', ') ?? '',
    );
    _preferencesLieuController = TextEditingController(
      text: (profile['preferencesLieu'] as List?)?.join(', ') ?? '',
    );

    _raisonSocialeController = TextEditingController(
      text: profile['raisonSociale']?.toString() ?? '',
    );
    _secteurActiviteController = TextEditingController(
      text: profile['secteurActivite']?.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: profile['description']?.toString() ?? '',
    );
    _siteWebController = TextEditingController(
      text: profile['siteWeb']?.toString() ?? '',
    );
    _nomEtablissementController = TextEditingController(
      text: profile['nomEtablissement']?.toString() ?? '',
    );

    _taille = profile['taille']?.toString() ?? 'PME';
    _statut = profile['statut']?.toString() ?? 'PRIVE';
  }

  @override
  void dispose() {
    for (final controller in [
      _prenomController,
      _nomController,
      _emailController,
      _telephoneController,
      _avatarController,
      _niveauController,
      _domaineController,
      _competencesController,
      _objectifController,
      _experiencesController,
      _preferencesSecteurController,
      _preferencesLieuController,
      _raisonSocialeController,
      _secteurActiviteController,
      _descriptionController,
      _siteWebController,
      _nomEtablissementController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = parseUserRole(widget.initialUser['role']?.toString());

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Modifier le profil',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prenomController,
              decoration: const InputDecoration(labelText: 'Prénom'),
              validator: (v) => _requiredField(v, 'Le prénom'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(labelText: 'Nom'),
              validator: (v) => _requiredField(v, 'Le nom'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Adresse e-mail'),
              validator: _validateEmail,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _telephoneController,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: _optionalPhoneValidator,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _avatarController,
              decoration: const InputDecoration(labelText: 'URL avatar'),
              validator: _optionalUrlValidator,
            ),
            const SizedBox(height: 14),
            ...switch (role) {
              UserRole.etudiant => _buildStudentFields(),
              UserRole.lyceen => _buildHighSchoolFields(),
              UserRole.entreprise => _buildCompanyFields(),
              UserRole.ecole => _buildSchoolFields(),
            },
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (!_formKey.currentState!.validate()) {
                  return;
                }
                Navigator.of(context).pop(_buildPayload(role));
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStudentFields() {
    return [
      TextFormField(
        controller: _niveauController,
        decoration: const InputDecoration(labelText: 'Niveau d’étude'),
        validator: (v) => _requiredField(v, 'Le niveau d’étude'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _domaineController,
        decoration: const InputDecoration(labelText: 'Domaine'),
        validator: (v) => _requiredField(v, 'Le domaine'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _competencesController,
        decoration: const InputDecoration(labelText: 'Compétences (csv)'),
        validator: _optionalCsvValidator,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _objectifController,
        decoration: const InputDecoration(labelText: 'Objectif'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _experiencesController,
        decoration: const InputDecoration(labelText: 'Expériences (csv)'),
        validator: _optionalCsvValidator,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _preferencesSecteurController,
        decoration: const InputDecoration(
          labelText: 'Préférences secteur (csv)',
        ),
        validator: _optionalCsvValidator,
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _preferencesLieuController,
        decoration: const InputDecoration(labelText: 'Préférences lieu (csv)'),
        validator: _optionalCsvValidator,
      ),
    ];
  }

  List<Widget> _buildHighSchoolFields() {
    return [
      TextFormField(
        controller: _niveauController,
        decoration: const InputDecoration(labelText: 'Classe actuelle'),
        validator: (v) => _requiredField(v, 'La classe actuelle'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _domaineController,
        decoration: const InputDecoration(labelText: 'Série / orientation'),
        validator: (v) => _requiredField(v, 'La série ou orientation'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _objectifController,
        decoration: const InputDecoration(labelText: 'Objectif post-bac'),
        validator: (v) => _requiredField(v, 'L\'objectif post-bac'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _competencesController,
        decoration: const InputDecoration(labelText: 'Centres d’intérêt (csv)'),
        validator: _optionalCsvValidator,
      ),
    ];
  }

  List<Widget> _buildCompanyFields() {
    return [
      TextFormField(
        controller: _raisonSocialeController,
        decoration: const InputDecoration(labelText: 'Raison sociale'),
        validator: (v) => _requiredField(v, 'La raison sociale'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _secteurActiviteController,
        decoration: const InputDecoration(labelText: 'Secteur d’activité'),
        validator: (v) => _requiredField(v, 'Le secteur'),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _taille,
        decoration: const InputDecoration(labelText: 'Taille'),
        items: const [
          DropdownMenuItem(value: 'MICRO', child: Text('MICRO')),
          DropdownMenuItem(value: 'PME', child: Text('PME')),
          DropdownMenuItem(value: 'ETI', child: Text('ETI')),
          DropdownMenuItem(value: 'GE', child: Text('GE')),
        ],
        onChanged: (value) => setState(() => _taille = value ?? 'PME'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(labelText: 'Description'),
        validator: (v) => _requiredField(v, 'La description'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _siteWebController,
        decoration: const InputDecoration(labelText: 'Site web'),
        validator: _optionalUrlValidator,
      ),
    ];
  }

  List<Widget> _buildSchoolFields() {
    return [
      TextFormField(
        controller: _nomEtablissementController,
        decoration: const InputDecoration(labelText: 'Nom établissement'),
        validator: (v) => _requiredField(v, 'Le nom établissement'),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _statut,
        decoration: const InputDecoration(labelText: 'Statut'),
        items: const [
          DropdownMenuItem(value: 'PUBLIC', child: Text('PUBLIC')),
          DropdownMenuItem(value: 'PRIVE', child: Text('PRIVE')),
        ],
        onChanged: (value) => setState(() => _statut = value ?? 'PRIVE'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _descriptionController,
        decoration: const InputDecoration(labelText: 'Description'),
      ),
      const SizedBox(height: 10),
      TextFormField(
        controller: _siteWebController,
        decoration: const InputDecoration(labelText: 'Site web'),
        validator: _optionalUrlValidator,
      ),
    ];
  }

  Map<String, dynamic> _buildPayload(UserRole role) {
    final payload = <String, dynamic>{
      'prenom': _prenomController.text.trim(),
      'nom': _nomController.text.trim(),
      'email': _emailController.text.trim(),
      'telephone': _telephoneController.text.trim(),
      'avatarUrl': _avatarController.text.trim(),
      'profil': switch (role) {
        UserRole.etudiant => {
          'niveauEtude': _niveauController.text.trim(),
          'domaine': _domaineController.text.trim(),
          'competences': _csvToList(_competencesController.text),
          'objectif': _objectifController.text.trim(),
          'experiences': _csvToList(_experiencesController.text),
          'preferencesSecteur': _csvToList(_preferencesSecteurController.text),
          'preferencesLieu': _csvToList(_preferencesLieuController.text),
        },
        UserRole.lyceen => {
          'classeActuelle': _niveauController.text.trim(),
          'serieOrientation': _domaineController.text.trim(),
          'objectifPostbac': _objectifController.text.trim(),
          'centresInteret': _csvToList(_competencesController.text),
        },
        UserRole.entreprise => {
          'raisonSociale': _raisonSocialeController.text.trim(),
          'secteurActivite': _secteurActiviteController.text.trim(),
          'taille': _taille,
          'description': _descriptionController.text.trim(),
          'siteWeb': _siteWebController.text.trim(),
        },
        UserRole.ecole => {
          'nomEtablissement': _nomEtablissementController.text.trim(),
          'statut': _statut,
          'description': _descriptionController.text.trim(),
          'siteWeb': _siteWebController.text.trim(),
        },
      },
    };

    payload.removeWhere((key, value) {
      if (value is String) {
        return value.trim().isEmpty;
      }
      return false;
    });

    final profile =
        (payload['profil'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    profile.removeWhere((key, value) {
      if (value is String) {
        return value.trim().isEmpty;
      }
      if (value is List) {
        return value.isEmpty;
      }
      return false;
    });

    payload['profil'] = profile;
    return payload;
  }

  List<String> _csvToList(String value) {
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }
}

class _SchoolFormSheet extends StatefulWidget {
  const _SchoolFormSheet({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_SchoolFormSheet> createState() => _SchoolFormSheetState();
}

class _SchoolFormSheetState extends State<_SchoolFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late final TextEditingController _domainesController;
  late final TextEditingController _diplomesController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _adresseController;
  late final TextEditingController _siteWebController;
  String _statut = 'PRIVE';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    _nomController = TextEditingController(
        text: initial['nomEtablissement']?.toString() ?? '');
    _domainesController = TextEditingController(
        text: ((initial['domaines'] as List?)
                ?.map((e) => e.toString())
                .join(', ')) ??
            '');
    _diplomesController = TextEditingController(
        text: ((initial['diplomesDelivres'] as List?)
                ?.map((e) => e.toString())
                .join(', ')) ??
            '');
    _descriptionController = TextEditingController(
        text: initial['description']?.toString() ?? '');
    _adresseController =
        TextEditingController(text: initial['adresse']?.toString() ?? '');
    _siteWebController =
        TextEditingController(text: initial['siteWeb']?.toString() ?? '');
    final s = initial['statut']?.toString().toUpperCase();
    if (s == 'PUBLIC' || s == 'PRIVE') _statut = s!;
  }

  @override
  void dispose() {
    _nomController.dispose();
    _domainesController.dispose();
    _diplomesController.dispose();
    _descriptionController.dispose();
    _adresseController.dispose();
    _siteWebController.dispose();
    super.dispose();
  }

  List<String> _csv(String v) => v
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'nomEtablissement': _nomController.text.trim(),
      'statut': _statut,
      'domaines': _csv(_domainesController.text),
      'diplomesDelivres': _csv(_diplomesController.text),
      'description': _descriptionController.text.trim(),
      'adresse': _adresseController.text.trim(),
      'siteWeb': _siteWebController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null
                    ? 'Créer ma fiche école'
                    : 'Modifier ma fiche école',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nomController,
                decoration: const InputDecoration(
                    labelText: 'Nom de l\'établissement *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Champ requis'
                    : null,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _statut,
                decoration: const InputDecoration(labelText: 'Statut'),
                items: const [
                  DropdownMenuItem(value: 'PUBLIC', child: Text('Public')),
                  DropdownMenuItem(value: 'PRIVE', child: Text('Privé')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _statut = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _domainesController,
                decoration: const InputDecoration(
                  labelText: 'Domaines (séparés par des virgules)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _diplomesController,
                decoration: const InputDecoration(
                  labelText: 'Diplômes délivrés (séparés par des virgules)',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _adresseController,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _siteWebController,
                decoration: const InputDecoration(labelText: 'Site web'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompanyFormSheet extends StatefulWidget {
  const _CompanyFormSheet({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_CompanyFormSheet> createState() => _CompanyFormSheetState();
}

class _CompanyFormSheetState extends State<_CompanyFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _raisonController;
  late final TextEditingController _secteurController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _adresseController;
  late final TextEditingController _siteWebController;
  late final TextEditingController _logoController;
  String _taille = 'PME';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    _raisonController = TextEditingController(
        text: initial['raisonSociale']?.toString() ?? '');
    _secteurController = TextEditingController(
        text: initial['secteurActivite']?.toString() ?? '');
    _descriptionController = TextEditingController(
        text: initial['description']?.toString() ?? '');
    _adresseController =
        TextEditingController(text: initial['adresse']?.toString() ?? '');
    _siteWebController =
        TextEditingController(text: initial['siteWeb']?.toString() ?? '');
    _logoController =
        TextEditingController(text: initial['logoUrl']?.toString() ?? '');
    final t = initial['taille']?.toString().toUpperCase();
    if (t == 'MICRO' || t == 'PME' || t == 'ETI' || t == 'GE') _taille = t!;
  }

  @override
  void dispose() {
    _raisonController.dispose();
    _secteurController.dispose();
    _descriptionController.dispose();
    _adresseController.dispose();
    _siteWebController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop({
      'raisonSociale': _raisonController.text.trim(),
      'secteurActivite': _secteurController.text.trim(),
      'taille': _taille,
      'description': _descriptionController.text.trim(),
      'adresse': _adresseController.text.trim(),
      'siteWeb': _siteWebController.text.trim(),
      'logoUrl': _logoController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null
                    ? 'Créer ma fiche entreprise'
                    : 'Modifier ma fiche entreprise',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _raisonController,
                decoration:
                    const InputDecoration(labelText: 'Raison sociale *'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Champ requis';
                  if (t.length < 2 || t.length > 150) {
                    return 'Doit faire entre 2 et 150 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _secteurController,
                decoration:
                    const InputDecoration(labelText: 'Secteur d\'activité'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _taille,
                decoration: const InputDecoration(labelText: 'Taille'),
                items: const [
                  DropdownMenuItem(value: 'MICRO', child: Text('Micro')),
                  DropdownMenuItem(value: 'PME', child: Text('PME')),
                  DropdownMenuItem(value: 'ETI', child: Text('ETI')),
                  DropdownMenuItem(value: 'GE', child: Text('Grande entreprise')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _taille = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _adresseController,
                decoration: const InputDecoration(labelText: 'Adresse'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _siteWebController,
                decoration: const InputDecoration(labelText: 'Site web'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _logoController,
                decoration: const InputDecoration(labelText: 'URL du logo'),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


