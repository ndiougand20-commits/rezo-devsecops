part of 'auth_flow.dart';

class _MatchesTab extends StatefulWidget {
  const _MatchesTab({super.key});

  @override
  State<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<_MatchesTab> {
  int _currentIndex = 0;
  int _likedCount = 0;
  int _passedCount = 0;
  bool _introScheduled = false;

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;
  bool _isDragging = false;

  bool _isLoading = true;
  String? _error;
  List<_MatchItem> _items = const <_MatchItem>[];
  Map<String, dynamic>? _suggestedPack;
  Map<String, dynamic>? _trace;
  bool _suggestedPackDismissed = false;
  bool _dataLoadScheduled = false;
  bool _isReplayMode = false;
  String? _selectedSecteur;

  static const List<String> _secteurOptions = <String>[
    'Informatique',
    'Medecine',
    'Droit',
    'Commerce',
    'Ingenierie',
    'Communication',
  ];

  String? _toAbsoluteMediaUrl(String? fileUrl) {
    final raw = fileUrl?.trim() ?? '';
    if (raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return '${HttpAuthService.defaultBaseUrl}$raw';
  }

  String? _pickFirstImageUrl(
    Map<String, dynamic> source, {
    List<Map>? mediaFiles,
  }) {
    const keys = <String>[
      'avatarUrl',
      'photoUrl',
      'imageUrl',
      'logoUrl',
      'ownerLogoUrl',
      'profilePhotoUrl',
      'ownerAvatarUrl',
      'ownerPhotoUrl',
    ];
    for (final key in keys) {
      final value = source[key]?.toString();
      final absolute = _toAbsoluteMediaUrl(value);
      if (absolute != null && absolute.isNotEmpty) return absolute;
    }
    if (mediaFiles != null) {
      for (final raw in mediaFiles) {
        final media = raw.cast<String, dynamic>();
        final category = media['category']?.toString().toUpperCase() ?? '';
        if (category == 'PHOTO' ||
            category == 'AVATAR' ||
            category == 'IMAGE') {
          final absolute = _toAbsoluteMediaUrl(media['fileUrl']?.toString());
          if (absolute != null && absolute.isNotEmpty) return absolute;
        }
      }
    }
    return null;
  }

  static const _introSeenKey = 'matching_intro_seen';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_introScheduled) {
      _introScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _maybeShowMatchingIntro();
      });
    }
    if (!_dataLoadScheduled) {
      _dataLoadScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadRecommendations();
      });
    }
  }

  Future<void> _maybeShowMatchingIntro() async {
    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_introSeenKey) ?? false;
    if (!mounted || alreadySeen) return;
    await _showMatchingIntro();
    await prefs.setBool(_introSeenKey, true);
  }

  Future<void> _loadRecommendations({bool includeSwiped = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
      _isReplayMode = includeSwiped;
    });
    final appState = AppScope.of(context);
    final user = appState.currentUser ?? const <String, dynamic>{};
    final role = parseUserRole(user['role'] as String?);
    try {
      List<_MatchItem> mapped;
      Map<String, dynamic>? suggested;
      if (role == UserRole.lyceen) {
        final data = await appState.fetchSchoolRecommendations(
          secteur: _selectedSecteur,
        );
        mapped = _mapSchoolRecommendations(data);
        final rawTrace = data['trace'];
        if (rawTrace is Map) {
          _trace = rawTrace.cast<String, dynamic>();
        } else {
          _trace = null;
        }
      } else if (role == UserRole.ecole || role == UserRole.entreprise) {
        final data = await appState.fetchProfileRecommendations(
          includeSwiped: includeSwiped,
        );
        mapped = _mapProfileRecommendations(data);
        final rawTrace = data['trace'];
        if (rawTrace is Map) {
          _trace = rawTrace.cast<String, dynamic>();
        } else {
          _trace = null;
        }
      } else {
        final data = await appState.fetchRecommendations(
          includeSwiped: includeSwiped,
        );
        mapped = _mapOfferRecommendations(data);
        final raw = data['suggestedPack'];
        if (raw is Map) {
          suggested = raw.cast<String, dynamic>();
        }
        final rawTrace = data['trace'];
        if (rawTrace is Map) {
          _trace = rawTrace.cast<String, dynamic>();
        } else {
          _trace = null;
        }
      }
      if (mapped.isEmpty && !includeSwiped && _canReplay(role)) {
        if (!mounted) return;
        return _loadRecommendations(includeSwiped: true);
      }
      if (!mounted) return;
      setState(() {
        _items = mapped;
        _suggestedPack = suggested;
        _isLoading = false;
        _currentIndex = 0;
        _likedCount = 0;
        _passedCount = 0;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Impossible de charger les recommandations';
      });
    }
  }

  List<_MatchItem> _mapOfferRecommendations(Map<String, dynamic> data) {
    final list = data['recommendations'];
    if (list is! List) return const <_MatchItem>[];
    final palette = const [
      Color(0xFFEEEEEE),
      Color(0xFFE8E8E8),
      Color(0xFFF0F0F0),
      Color(0xFFE3E3E3),
    ];
    final result = <_MatchItem>[];
    var i = 0;
    for (final entry in list) {
      if (entry is! Map) continue;
      final item = entry.cast<String, dynamic>();
      final offer =
          (item['offer'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final reasonsRaw = item['reasons'];
      final reasons = reasonsRaw is List
          ? reasonsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final compsRaw = offer['competencesRequises'];
      final comps = compsRaw is List
          ? compsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final tags = <String>[
        if (offer['domaine'] != null) offer['domaine'].toString(),
        ...comps.take(2),
      ];
      final owner = offer['ownerDisplayName']?.toString() ?? '—';
      final location = offer['location']?.toString() ?? '—';
      final type = offer['type']?.toString() ?? 'OPPORTUNITE';
      final avatarUrl = _pickFirstImageUrl(offer) ?? _pickFirstImageUrl(item);
      // fallback : chercher dans l'objet owner imbriqué si présent
      final ownerMap = (item['owner'] as Map?)?.cast<String, dynamic>();
      final resolvedAvatarUrl =
          avatarUrl ?? (ownerMap != null ? _pickFirstImageUrl(ownerMap) : null);
      result.add(
        _MatchItem(
          offerId: item['offerId']?.toString() ?? offer['id']?.toString(),
          title: offer['titre']?.toString() ?? 'Sans titre',
          subtitle: '$owner \u2022 $location',
          score: (item['score'] is num)
              ? (item['score'] as num).round()
              : int.tryParse('${item['score']}') ?? 0,
          owner: owner,
          location: location,
          typeLabel: type,
          accent: palette[i % palette.length],
          tags: tags,
          reasons: reasons,
          description: offer['description']?.toString() ?? '',
          avatarUrl: resolvedAvatarUrl,
          ruleScore: (item['ruleScore'] as num?)?.toDouble(),
          mlProbability: (item['mlProbability'] as num?)?.toDouble(),
          modelVersion: item['modelVersion']?.toString(),
          algorithm: item['algorithm']?.toString(),
        ),
      );
      i++;
    }
    return result;
  }

  List<_MatchItem> _mapSchoolRecommendations(Map<String, dynamic> data) {
    final list = data['recommendations'];
    if (list is! List) return const <_MatchItem>[];
    final palette = const [
      Color(0xFFEEEEEE),
      Color(0xFFF0F0F0),
      Color(0xFFE8E8E8),
    ];
    final result = <_MatchItem>[];
    var i = 0;
    for (final entry in list) {
      if (entry is! Map) continue;
      final item = entry.cast<String, dynamic>();
      final school =
          (item['school'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      final reasonsRaw = item['reasons'];
      final reasons = reasonsRaw is List
          ? reasonsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final domainesRaw = school['domaines'];
      final domaines = domainesRaw is List
          ? domainesRaw.map((e) => e.toString()).toList()
          : <String>[];
      final avatarUrl = _pickFirstImageUrl(school) ?? _pickFirstImageUrl(item);
      result.add(
        _MatchItem(
          title: school['nomEtablissement']?.toString() ?? 'Ecole',
          subtitle:
              '${school['statut'] ?? ''} \u2022 ${school['adresse'] ?? ''}'
                  .trim(),
          score: (item['score'] is num) ? (item['score'] as num).round() : 0,
          owner: school['nomEtablissement']?.toString() ?? '—',
          location: school['adresse']?.toString() ?? '—',
          typeLabel: 'ECOLE',
          accent: palette[i % palette.length],
          tags: domaines.take(3).toList(),
          reasons: reasons,
          description: school['description']?.toString() ?? '',
          avatarUrl: avatarUrl,
        ),
      );
      i++;
    }
    return result;
  }

  List<_MatchItem> _mapProfileRecommendations(Map<String, dynamic> data) {
    final list = data['recommendations'];
    if (list is! List) return const <_MatchItem>[];
    final palette = const [
      Color(0xFFF0F0F0),
      Color(0xFFECECEC),
      Color(0xFFE8E8E8),
      Color(0xFFF4F4F4),
    ];
    final result = <_MatchItem>[];
    var i = 0;
    for (final entry in list) {
      if (entry is! Map) continue;
      final item = entry.cast<String, dynamic>();
      final reasonsRaw = item['reasons'];
      final reasons = reasonsRaw is List
          ? reasonsRaw.map((e) => e.toString()).toList()
          : <String>[];
      final competencesRaw = item['competences'];
      final competences = competencesRaw is List
          ? competencesRaw.map((e) => e.toString()).toList()
          : <String>[];
      final mediaRaw = item['mediaFiles'];
      final media = mediaRaw is List
          ? mediaRaw.whereType<Map>().toList()
          : const <Map>[];
      final categories = media
          .map((m) => m['category']?.toString().toUpperCase() ?? '')
          .where((c) => c.isNotEmpty)
          .toSet();

      final docTags = <String>[
        if (categories.contains('CV')) 'CV',
        if (categories.contains('LM')) 'LM',
        if (categories.contains('DIPLOME')) 'Diplome',
        if (categories.contains('BULLETIN')) 'Bulletin',
      ];

      final prenom = item['prenom']?.toString().trim() ?? '';
      final nom = item['nom']?.toString().trim() ?? '';
      final fullName = ('$prenom $nom').trim().isEmpty
          ? 'Profil'
          : ('$prenom $nom').trim();
      final niveau = item['niveauEtude']?.toString() ?? '';
      final domaine = item['domaine']?.toString() ?? '';
      final subtitle = [
        niveau,
        domaine,
      ].where((e) => e.trim().isNotEmpty).join(' • ');
      final tags = <String>[
        if (domaine.trim().isNotEmpty) domaine,
        ...competences.take(3),
        ...docTags,
      ];
      final avatarUrl = _pickFirstImageUrl(item, mediaFiles: media);

      result.add(
        _MatchItem(
          title: fullName,
          subtitle: subtitle.isEmpty ? 'Profil recommande' : subtitle,
          score: (item['score'] is num)
              ? (item['score'] as num).round()
              : int.tryParse('${item['score']}') ?? 0,
          owner: fullName,
          location: item['location']?.toString() ?? '—',
          typeLabel: 'PROFIL',
          accent: palette[i % palette.length],
          tags: tags,
          reasons: reasons,
          description: item['objectif']?.toString() ?? '',
          targetUserId: item['userId']?.toString(),
          avatarUrl: avatarUrl,
        ),
      );
      i++;
    }
    return result;
  }

  void _onPanStart(DragStartDetails _) {
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = _dragOffset.dx / 300 * 0.3;
    });
  }

  void _onPanEnd(DragEndDetails _, int total) {
    final dx = _dragOffset.dx;
    if (dx.abs() > 100) {
      final current = _currentIndex < _items.length
          ? _items[_currentIndex]
          : null;
      _swipe(
        liked: dx > 0,
        total: total,
        offerId: current?.offerId,
        targetUserId: current?.targetUserId,
      );
    }
    setState(() {
      _dragOffset = Offset.zero;
      _dragAngle = 0;
      _isDragging = false;
    });
  }

  void _swipe({
    required bool liked,
    required int total,
    String? offerId,
    String? targetUserId,
  }) {
    final nextIndex = _currentIndex + 1;
    setState(() {
      if (liked) {
        _likedCount += 1;
      } else {
        _passedCount += 1;
      }
      _currentIndex = nextIndex.clamp(0, total);
      _dragOffset = Offset.zero;
      _dragAngle = 0;
      _isDragging = false;
    });

    // Fire-and-forget: enregistrer le swipe cote backend (ignorer les erreurs).
    if (offerId != null && offerId.isNotEmpty) {
      final appState = AppScope.of(context);
      unawaited(
        appState
            .recordSwipe(offerId: offerId, action: liked ? 'LIKE' : 'DISLIKE')
            .catchError((Object _) => <String, dynamic>{}),
      );
    } else if (targetUserId != null && targetUserId.isNotEmpty) {
      final appState = AppScope.of(context);
      unawaited(
        appState
            .recordProfileSwipe(
              targetUserId: targetUserId,
              action: liked ? 'LIKE' : 'DISLIKE',
            )
            .catchError((Object _) => <String, dynamic>{}),
      );
    }

    if (!mounted) return;

    final message = liked
        ? 'Ajout\u00e9 \u00e0 tes favoris'
        : 'Suggestion ignor\u00e9e';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
    );
  }

  void _resetSession() {
    setState(() {
      _currentIndex = 0;
      _likedCount = 0;
      _passedCount = 0;
    });
  }

  void _showMatchDetail(_MatchItem match) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _MatchDetailSheet(match: match),
    );
  }

  Future<void> _showMatchingIntro() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: const Text(
            'Comment fonctionne le matching',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Decouvre chaque profil une carte a la fois.',
                style: TextStyle(height: 1.4),
              ),
              SizedBox(height: 16),
              _IntroStep(
                icon: Icons.swipe_right_rounded,
                title: 'Glisse a droite',
                subtitle: 'pour garder une opportunite dans tes favoris.',
              ),
              SizedBox(height: 12),
              _IntroStep(
                icon: Icons.swipe_left_rounded,
                title: 'Glisse a gauche',
                subtitle: 'pour passer a la suggestion suivante.',
              ),
              SizedBox(height: 12),
              _IntroStep(
                icon: Icons.info_outline_rounded,
                title: 'Touche le cercle',
                subtitle: 'pour ouvrir la fiche et comprendre le match.',
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('J\'ai compris'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.black54,
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadRecommendations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('R\u00e9essayer'),
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

    final recommendations = _items;
    final appState = AppScope.of(context);
    final role = parseUserRole(appState.currentUser?['role'] as String?);

    if (recommendations.isEmpty) {
      final emptyMessage = _buildEmptyMessage(role);
      final canReplay = _canReplay(role);
      return RefreshIndicator(
        onRefresh: () => _loadRecommendations(includeSwiped: _isReplayMode),
        child: ListView(
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 64,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(80),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        emptyMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, height: 1.4),
                      ),
                      if (canReplay) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () =>
                              _loadRecommendations(includeSwiped: true),
                          icon: const Icon(Icons.replay_rounded),
                          label: const Text('Reparcourir les opportunites'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasCurrent = _currentIndex < recommendations.length;
    final current = hasCurrent ? recommendations[_currentIndex] : null;
    final prev = _currentIndex > 0 ? recommendations[_currentIndex - 1] : null;
    final next = _currentIndex + 1 < recommendations.length
        ? recommendations[_currentIndex + 1]
        : null;
    return Column(
      children: [
        if (role == UserRole.lyceen) _buildSecteurFilters(),
        // Swipe area
        Expanded(
          child: current != null
              ? _buildSwipeStack(current, prev, next, recommendations.length)
              : _buildSessionEnd(recommendations.length),
        ),

        if (current != null)
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Text(
              'Glisse la carte pour choisir, ou touche le cercle pour voir la fiche.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF616161),
                fontWeight: FontWeight.w500,
              ),
            ),
          )
        else
          const SizedBox(height: 24),
        if (_suggestedPack != null && !_suggestedPackDismissed)
          _buildSuggestedPackBanner(),
      ],
    );
  }

  Widget _buildSecteurFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: const Text('Tous'),
                selected: _selectedSecteur == null,
                onSelected: (_) {
                  if (_selectedSecteur == null) return;
                  setState(() => _selectedSecteur = null);
                  _loadRecommendations();
                },
              ),
            ),
            ..._secteurOptions.map(
              (secteur) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(secteur),
                  selected: _selectedSecteur == secteur,
                  onSelected: (_) {
                    if (_selectedSecteur == secteur) return;
                    setState(() => _selectedSecteur = secteur);
                    _loadRecommendations();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildEmptyMessage(UserRole role) {
    final trace = _trace ?? const <String, dynamic>{};
    final hasAccess = trace['hasOpportunityAccess'];
    final availableOfferCount = (trace['availableOfferCount'] as num?)?.toInt();
    final excludedSwipeCount =
        (trace['excludedSwipeCount'] as num?)?.toInt() ?? 0;
    final evaluatedCount = (trace['evaluatedCount'] as num?)?.toInt() ?? 0;

    if (role == UserRole.lyceen) {
      return 'Aucune ecole recommandee pour le moment.\nReessaie plus tard ou ajuste tes centres d\'interet.';
    }

    if (hasAccess is bool && !hasAccess) {
      return 'Ton pack actuel ne permet pas d\'afficher les opportunites.\nPasse a une offre avec matching pour debloquer les suggestions.';
    }

    if (availableOfferCount != null && availableOfferCount == 0) {
      return 'Aucune opportunite publiee pour le moment.\nReviens plus tard.';
    }

    if (evaluatedCount == 0 && excludedSwipeCount > 0 && !_isReplayMode) {
      return 'Aucune nouvelle opportunite disponible pour le moment.\nTu peux reparcourir les profils precedemment ignores.';
    }

    if (_isReplayMode) {
      return 'Aucune opportunite a reparcourir pour le moment.\nReessaie plus tard.';
    }

    return 'Aucune suggestion disponible pour le moment.\nReessaie dans quelques instants.';
  }

  bool _canReplay(UserRole role) {
    if (role == UserRole.lyceen || _isReplayMode) return false;
    final trace = _trace ?? const <String, dynamic>{};
    final excludedSwipeCount =
        (trace['excludedSwipeCount'] as num?)?.toInt() ?? 0;
    final hasAccess = trace['hasOpportunityAccess'];
    return excludedSwipeCount > 0 && (hasAccess is! bool || hasAccess);
  }

  Widget _buildSuggestedPackBanner() {
    final label = _suggestedPack?['label']?.toString() ?? 'sup\u00e9rieur';
    final reason = _suggestedPack?['reason']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pack sugg\u00e9r\u00e9 : $label',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                if (reason.isNotEmpty)
                  Text(
                    reason,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _suggestedPackDismissed = true),
            tooltip: 'Masquer',
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeStack(
    _MatchItem current,
    _MatchItem? prev,
    _MatchItem? next,
    int total,
  ) {
    // L'amplitude du drag (0..1) réduit la carte arrière au fur et à mesure
    final dragProgress = (_dragOffset.dx.abs() / 150).clamp(0.0, 1.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        // ── Bulle précédente (derrière, à gauche) ──
        if (prev != null)
          Positioned(
            left: 0,
            child: Opacity(
              opacity: (0.45 + dragProgress * 0.35).clamp(0.0, 0.8),
              child: Transform.scale(
                scale: 0.72 + dragProgress * 0.06,
                child: _buildCardBubble(prev),
              ),
            ),
          ),

        // ── Bulle suivante (derrière, à droite) ──
        if (next != null)
          Positioned(
            right: 0,
            child: Opacity(
              opacity: (0.45 + dragProgress * 0.35).clamp(0.0, 0.8),
              child: Transform.scale(
                scale: 0.72 + dragProgress * 0.06,
                child: _buildCardBubble(next),
              ),
            ),
          ),

        // ── Carte principale (au premier plan) ──
        _buildSwipeCard(current, total),
      ],
    );
  }

  /// Rendu simplifié d'une bulle de fond (sans interaction).
  Widget _buildCardBubble(_MatchItem match) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            match.accent,
            Theme.of(context).colorScheme.primaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFE0E0E0), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: match.accent.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE0E0E0)),
            ),
            clipBehavior: Clip.antiAlias,
            child: (match.avatarUrl != null && match.avatarUrl!.isNotEmpty)
                ? Image.network(
                    match.avatarUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Text(
                        _initials(match.title),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  )
                : Center(
                    child: Text(
                      _initials(match.title),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              match.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeCard(_MatchItem match, int total) {
    final swipeProgress = (_dragOffset.dx / 150).clamp(-1.0, 1.0);
    final likeOpacity = swipeProgress > 0 ? swipeProgress : 0.0;
    final passOpacity = swipeProgress < 0 ? -swipeProgress : 0.0;

    return GestureDetector(
      onTap: () => _showMatchDetail(match),
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: (d) => _onPanEnd(d, total),
      child: Center(
        child: AnimatedContainer(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..setTranslationRaw(_dragOffset.dx, _dragOffset.dy, 0)
            ..rotateZ(_dragAngle),
          transformAlignment: Alignment.center,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      match.accent,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: match.accent.withAlpha(60),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 106,
                      height: 106,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child:
                          (match.avatarUrl != null &&
                              match.avatarUrl!.isNotEmpty)
                          ? Image.network(
                              match.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Center(
                                    child: Text(
                                      _initials(match.title),
                                      style: TextStyle(
                                        fontSize: 34,
                                        fontWeight: FontWeight.w900,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                            )
                          : Center(
                              child: Text(
                                _initials(match.title),
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        match.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        match.subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(200),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${match.score}% compatible',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFD0D0D0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(10),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    match.typeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (likeOpacity > 0)
                Positioned(
                  top: 20,
                  left: 20,
                  child: Opacity(
                    opacity: likeOpacity,
                    child: Transform.rotate(
                      angle: -0.3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF4CAF50),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LIKE',
                          style: TextStyle(
                            color: Color(0xFF4CAF50),
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (passOpacity > 0)
                Positioned(
                  top: 20,
                  right: 20,
                  child: Opacity(
                    opacity: passOpacity,
                    child: Transform.rotate(
                      angle: 0.3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFF5252),
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'NOPE',
                          style: TextStyle(
                            color: Color(0xFFFF5252),
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionEnd(int total) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE3E3E3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '$total profils parcourus',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$_likedCount aim\u00e9s  \u2022  $_passedCount pass\u00e9s',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF111111), Color(0xFF2A2A2A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(28),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _resetSession,
                    icon: const Icon(Icons.replay_rounded, size: 18),
                    label: const Text('Rejouer les profils'),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// Supporting widgets

class _IntroStep extends StatelessWidget {
  const _IntroStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 18, color: Colors.black),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(height: 1.35)),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchItem {
  const _MatchItem({
    required this.title,
    required this.subtitle,
    required this.score,
    required this.owner,
    required this.location,
    required this.typeLabel,
    required this.accent,
    required this.tags,
    required this.reasons,
    required this.description,
    this.avatarUrl,
    this.offerId,
    this.targetUserId,
    this.ruleScore,
    this.mlProbability,
    this.modelVersion,
    this.algorithm,
  });

  final String title;
  final String subtitle;
  final int score;
  final String owner;
  final String location;
  final String typeLabel;
  final Color accent;
  final List<String> tags;
  final List<String> reasons;
  final String description;
  final String? avatarUrl;
  final String? offerId;
  final String? targetUserId;
  final double? ruleScore;
  final double? mlProbability;
  final String? modelVersion;
  final String? algorithm;

  bool get usesHybridAi => algorithm == 'HYBRID_LOGISTIC_REGRESSION';
}

class _MatchDetailSheet extends StatelessWidget {
  const _MatchDetailSheet({required this.match});

  final _MatchItem match;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Avatar circle
            Center(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      match.accent,
                      Theme.of(context).colorScheme.primaryContainer,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: const Color(0xFFE0E0E0), width: 3),
                ),
                child: Center(
                  child:
                      (match.avatarUrl != null && match.avatarUrl!.isNotEmpty)
                      ? ClipOval(
                          child: Image.network(
                            match.avatarUrl!,
                            width: 148,
                            height: 148,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Text(
                              _initials(match.title),
                              style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          _initials(match.title),
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${match.score}% compatible',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              match.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              match.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 20),
            _ProfileSectionCard(
              title: 'Description',
              child: Text(
                match.description,
                style: const TextStyle(height: 1.45),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileSectionCard(
              title: 'Informations',
              child: Column(
                children: [
                  _DetailRow(
                    icon: Icons.business_center_rounded,
                    label: 'Propos\u00e9 par',
                    value: match.owner,
                  ),
                  _DetailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Localisation',
                    value: match.location,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _ProfileSectionCard(
              title: 'Tags',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: match.tags.map((t) => _TagPill(label: t)).toList(),
              ),
            ),
            const SizedBox(height: 12),
            _ProfileSectionCard(
              title: 'Pourquoi cette suggestion',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: match.reasons
                    .map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(r)),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (match.usesHybridAi) ...[
              const SizedBox(height: 12),
              _ProfileSectionCard(
                title: 'Calcul de la compatibilité',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'IA hybride : le score combine les critères du profil '
                      'et un modèle qui apprend progressivement des LIKE/DISLIKE.',
                      style: TextStyle(height: 1.4),
                    ),
                    if (match.mlProbability != null) ...[
                      const SizedBox(height: 10),
                      _DetailRow(
                        icon: Icons.psychology_alt_rounded,
                        label: 'Probabilité IA',
                        value: '${(match.mlProbability! * 100).round()} %',
                      ),
                    ],
                    if (match.ruleScore != null)
                      _DetailRow(
                        icon: Icons.rule_rounded,
                        label: 'Score métier',
                        value: '${match.ruleScore!.round()} %',
                      ),
                    if (match.modelVersion != null)
                      Text(
                        'Version du modèle : ${match.modelVersion}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            '$label : ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
