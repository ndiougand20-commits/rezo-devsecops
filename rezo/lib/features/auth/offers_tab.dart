part of 'auth_flow.dart';

class _OffersTab extends StatefulWidget {
  const _OffersTab({super.key});

  @override
  State<_OffersTab> createState() => _OffersTabState();
}

class _OffersTabState extends State<_OffersTab> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = const <Map<String, dynamic>>[];
  Map<String, int> _likedCountByOfferId = const <String, int>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoading && _offers.isEmpty && _error == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadOffers();
      });
    }
  }

  Future<void> _loadOffers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final appState = AppScope.of(context);
      final myId = appState.currentUser?['id']?.toString() ?? '';
      final all = await appState.fetchOffers();
      final mine = all
          .where((o) =>
              o['ownerUserId']?.toString() == myId ||
              o['userId']?.toString() == myId)
          .toList();
      mine.sort((a, b) {
        final da = a['datePublication']?.toString() ??
            a['createdAt']?.toString() ??
            '';
        final db = b['datePublication']?.toString() ??
            b['createdAt']?.toString() ??
            '';
        return db.compareTo(da);
      });
      final likedCountByOfferId = await _loadLikedCountsForOffers(mine);
      if (!mounted) return;
      setState(() {
        _offers = mine;
        _likedCountByOfferId = likedCountByOfferId;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les offres';
        _likedCountByOfferId = const <String, int>{};
        _isLoading = false;
      });
    }
  }

  Future<Map<String, int>> _loadLikedCountsForOffers(
    List<Map<String, dynamic>> offers,
  ) async {
    final appState = AppScope.of(context);
    final counts = <String, int>{};

    await Future.wait(
      offers.map((offer) async {
        final id = offer['id']?.toString();
        if (id == null || id.isEmpty) return;

        try {
          final data = await appState.getOfferLikedBy(id);
          counts[id] = _extractLikedCount(data);
        } catch (_) {
          counts[id] = 0;
        }
      }),
    );

    return counts;
  }

  int _extractLikedCount(Map<String, dynamic> data) {
    final direct = (data['count'] as num?)?.toInt();
    if (direct != null) return direct;

    final users = data['users'];
    if (users is List) return users.length;

    final items = data['items'];
    if (items is List) return items.length;

    final likers = data['likers'];
    if (likers is List) return likers.length;

    return 0;
  }

  int _likedCountForOffer(Map<String, dynamic> offer) {
    final id = offer['id']?.toString();
    if (id == null || id.isEmpty) return 0;
    return _likedCountByOfferId[id] ?? 0;
  }

  Future<void> _openOfferSheet({Map<String, dynamic>? existing}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _OfferFormSheet(initial: existing),
    );
    if (result == null || !mounted) return;
    try {
      final appState = AppScope.of(context);
      final payload = Map<String, dynamic>.from(result)
        ..remove('_offerPdfBytes')
        ..remove('_offerPdfName');
      final pdfBytes = result['_offerPdfBytes'] as Uint8List?;
      final pdfName = result['_offerPdfName']?.toString();
      String? offerId;
      if (existing == null) {
        final created = await appState.createOffer(payload);
        offerId = created['id']?.toString();
        _snack('Offre créée');
      } else {
        offerId = existing['id']?.toString();
        if (offerId == null) throw const FormatException('ID offre manquant');
        await appState.updateOffer(offerId, payload);
        _snack('Offre mise à jour');
      }
      if (pdfBytes != null && pdfName != null && pdfName.isNotEmpty) {
        if (offerId == null || offerId.isEmpty) {
          throw const FormatException('ID offre manquant pour upload PDF');
        }
        await appState.uploadOfferPdf(
          offerId: offerId,
          bytes: pdfBytes,
          fileName: pdfName,
        );
        _snack('PDF de l\'offre joint');
      }
      await _loadOffers();
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) {
        _snack(e.message);
      } else {
        _snack(e.message);
      }
    } catch (_) {
      _snack('Sauvegarde impossible');
    }
  }

  Future<void> _deleteOffer(Map<String, dynamic> offer) async {
    final id = offer['id']?.toString();
    if (id == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette offre ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await AppScope.of(context).deleteOffer(id);
      _snack('Offre supprimée');
      await _loadOffers();
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Suppression impossible');
    }
  }

  Future<void> _showLikedBy(Map<String, dynamic> offer) async {
    final id = offer['id']?.toString();
    if (id == null) return;
    try {
      final data = await AppScope.of(context).getOfferLikedBy(id);
      if (!mounted) return;
      final users = (data['likers'] as List?) ??
          (data['users'] as List?) ??
          (data['items'] as List?) ??
          const <dynamic>[];
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _LikedByList(
          offerTitle: offer['titre']?.toString() ?? 'Offre',
          users: users
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList(),
        ),
      );
    } on AuthException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Impossible de récupérer les likes');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.currentUser ?? const <String, dynamic>{};
    final canManage = user['canManageOffers'] == true;

    if (!canManage) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Pack insuffisant',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              const Text(
                "Votre pack actuel ne permet pas de publier des offres.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () {
                  final shell = context
                      .findAncestorStateOfType<_DashboardScreenState>();
                  shell?.goToProfile();
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Voir les packs'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadOffers,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openOfferSheet(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle offre'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: _offers.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Aucune offre publiée. Crée ta première offre !",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: _offers.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final o = _offers[i];
                  final hasPublication =
                      (o['datePublication']?.toString() ?? '').isNotEmpty;
                  final statusLabel = hasPublication ? 'PUBLIÉ' : 'BROUILLON';
                  final dateFin = o['dateFin']?.toString() ?? '';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                o['titre']?.toString() ?? 'Offre',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasPublication
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                statusLabel,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if ((o['type']?.toString() ?? '').isNotEmpty)
                              _TagPill(label: o['type'].toString()),
                            if ((o['location']?.toString() ?? '').isNotEmpty)
                              _TagPill(label: o['location'].toString()),
                          ],
                        ),
                        if (dateFin.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Fin : $dateFin',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.black54)),
                        ],
                        if ((o['pdfUrl']?.toString() ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const _TagPill(label: 'PDF joint'),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _showLikedBy(o),
                              icon: const Icon(Icons.favorite_outline_rounded,
                                  size: 16),
                              label: Text('Likés (${_likedCountForOffer(o)})'),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () =>
                                  _openOfferSheet(existing: o),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteOffer(o),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _LikedByList extends StatelessWidget {
  const _LikedByList({required this.offerTitle, required this.users});
  final String offerTitle;
  final List<Map<String, dynamic>> users;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, controller) {
        return ListView(
          controller: controller,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Likés : $offerTitle',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (users.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Personne pour le moment.')),
              )
            else
              ...users.map((u) {
                final name = [
                  u['prenom']?.toString() ?? '',
                  u['nom']?.toString() ?? '',
                ].where((s) => s.isNotEmpty).join(' ');
                final display =
                    name.isNotEmpty ? name : (u['email']?.toString() ?? '—');
                final initial =
                    display.isNotEmpty ? display[0].toUpperCase() : '?';
                final avatarUrl = u['avatarUrl']?.toString();
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF0F0F0),
                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(initial,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700))
                        : null,
                  ),
                  title: Text(display),
                  subtitle: Text(u['role']?.toString() ?? ''),
                );
              }),
          ],
        );
      },
    );
  }
}

class _OfferFormSheet extends StatefulWidget {
  const _OfferFormSheet({this.initial});
  final Map<String, dynamic>? initial;

  @override
  State<_OfferFormSheet> createState() => _OfferFormSheetState();
}

class _OfferFormSheetState extends State<_OfferFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titreController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _domaineController;
  late final TextEditingController _locationController;
  late final TextEditingController _competencesController;
  String _type = 'STAGE';
  DateTime? _datePublication;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  Uint8List? _offerPdfBytes;
  String? _offerPdfName;
  String? _existingPdfUrl;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial ?? const <String, dynamic>{};
    _titreController =
        TextEditingController(text: initial['titre']?.toString() ?? '');
    _descriptionController = TextEditingController(
        text: initial['description']?.toString() ?? '');
    _domaineController =
        TextEditingController(text: initial['domaine']?.toString() ?? '');
    _locationController =
        TextEditingController(text: initial['location']?.toString() ?? '');
    _competencesController = TextEditingController(
        text: ((initial['competencesRequises'] as List?)
                ?.map((e) => e.toString())
                .join(', ')) ??
            '');
    final t = initial['type']?.toString().toUpperCase();
    if (t == 'STAGE' || t == 'EMPLOI' || t == 'FORMATION') _type = t!;
    _datePublication = _tryParse(initial['datePublication']);
    _dateDebut = _tryParse(initial['dateDebut']);
    _dateFin = _tryParse(initial['dateFin']);
    _existingPdfUrl = initial['pdfUrl']?.toString();
  }

  DateTime? _tryParse(dynamic v) {
    final s = v?.toString();
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  @override
  void dispose() {
    _titreController.dispose();
    _descriptionController.dispose();
    _domaineController.dispose();
    _locationController.dispose();
    _competencesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(
      DateTime? current, void Function(DateTime?) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    onPicked(picked);
    setState(() {});
  }

  String _fmt(DateTime? d) =>
      d == null ? 'Non défini' : '${d.year}-${_p(d.month)}-${_p(d.day)}';
  String _p(int v) => v < 10 ? '0$v' : '$v';

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final comps = _competencesController.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    Navigator.of(context).pop({
      'titre': _titreController.text.trim(),
      'description': _descriptionController.text.trim(),
      'type': _type,
      'domaine': _domaineController.text.trim(),
      'location': _locationController.text.trim(),
      'competencesRequises': comps,
      if (_datePublication != null)
        'datePublication': _datePublication!.toIso8601String(),
      if (_dateDebut != null) 'dateDebut': _dateDebut!.toIso8601String(),
      if (_dateFin != null) 'dateFin': _dateFin!.toIso8601String(),
      if (_offerPdfBytes != null) '_offerPdfBytes': _offerPdfBytes,
      if (_offerPdfName != null) '_offerPdfName': _offerPdfName,
    });
  }

  Future<void> _pickOfferPdf() async {
    final picked = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _offerPdfBytes = bytes;
      _offerPdfName = file.name;
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
                widget.initial == null ? 'Nouvelle offre' : 'Modifier l\'offre',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titreController,
                decoration: const InputDecoration(labelText: 'Titre *'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 2 || t.length > 150) {
                    return 'Entre 2 et 150 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Description *'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 10 || t.length > 5000) {
                    return 'Entre 10 et 5000 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: const [
                  DropdownMenuItem(value: 'STAGE', child: Text('Stage')),
                  DropdownMenuItem(value: 'EMPLOI', child: Text('Emploi')),
                  DropdownMenuItem(
                      value: 'FORMATION', child: Text('Formation')),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _domaineController,
                decoration: const InputDecoration(labelText: 'Domaine'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Localisation'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _competencesController,
                decoration: const InputDecoration(
                  labelText: 'Compétences requises (CSV)',
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date de publication'),
                subtitle: Text(_fmt(_datePublication)),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () => _pickDate(
                    _datePublication, (d) => _datePublication = d),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date de début'),
                subtitle: Text(_fmt(_dateDebut)),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () => _pickDate(_dateDebut, (d) => _dateDebut = d),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date de fin'),
                subtitle: Text(_fmt(_dateFin)),
                trailing: const Icon(Icons.calendar_today_rounded),
                onTap: () => _pickDate(_dateFin, (d) => _dateFin = d),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickOfferPdf,
                      icon: const Icon(Icons.picture_as_pdf_rounded),
                      label: const Text('Joindre un PDF'),
                    ),
                  ),
                ],
              ),
              if (_offerPdfName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Nouveau PDF: $_offerPdfName',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ] else if ((_existingPdfUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  'PDF déjà joint à cette offre.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
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
