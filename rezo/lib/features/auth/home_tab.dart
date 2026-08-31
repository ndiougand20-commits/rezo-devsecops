part of 'auth_flow.dart';

class _DashboardItem {
  const _DashboardItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});

  final _DashboardItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E6E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item.icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.item});

  final _DashboardItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black.withValues(alpha: 0.55),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({
    required this.user,
    required this.role,
    required this.fullName,
  });

  final Map<String, dynamic> user;
  final UserRole role;
  final String fullName;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  int? _matchCount;
  int? _likesReceived;
  int? _unreadMessages;
  int? _publishedOffers;
  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadDynamicData();
      });
    }
  }

  Future<void> _loadDynamicData() async {
    final appState = AppScope.of(context);

    final stats = await appState.fetchMyStats().catchError(
      (Object _) => <String, dynamic>{},
    );

    if (!mounted) return;
    final matchCount = (stats['matchCount'] as num?)?.toInt() ?? 0;
    final likesReceived = (stats['likesReceived'] as num?)?.toInt() ?? 0;
    final unread = (stats['unreadMessages'] as num?)?.toInt() ?? 0;
    final published = (stats['offerCount'] as num?)?.toInt() ?? 0;

    setState(() {
      _matchCount = matchCount;
      _likesReceived = likesReceived;
      _unreadMessages = unread;
      _publishedOffers = published;
    });
  }

  bool _shouldShowCompletenessBanner(Map<String, dynamic> profile) {
    switch (widget.role) {
      case UserRole.etudiant:
        return _isEmpty(profile['domaine']) || _isEmpty(profile['objectif']);
      case UserRole.lyceen:
        return _isEmpty(profile['objectifPostbac']);
      case UserRole.entreprise:
      case UserRole.ecole:
        // Géré par profile_tab via fiche manquante
        return false;
    }
  }

  bool _isEmpty(dynamic v) {
    if (v == null) return true;
    if (v is String) return v.trim().isEmpty;
    if (v is List) return v.isEmpty;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final role = widget.role;
    final fullName = widget.fullName;
    final profile = resolveUserProfile(user);
    final welcomeName = fullName.trim().isEmpty ? 'sur REZO' : fullName.trim();
    final highlights = _buildHighlights(profile, role);
    final showCompleteBanner = _shouldShowCompletenessBanner(profile);
    final packLabel = (user['packNom']?.toString().trim().isNotEmpty == true)
        ? user['packNom'].toString()
        : 'Pack FREE';
    final packLevel = user['packNiveau']?.toString();

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final tagline = switch (role) {
          UserRole.etudiant =>
            'Explore des opportunités, complète ton profil et lance tes premiers matchs.',
          UserRole.lyceen =>
            'Clarifie ton orientation, découvre les formations pertinentes et prépare ton post-bac.',
          UserRole.entreprise =>
            'Publie une offre, qualifie des candidats et démarre des conversations utiles.',
          UserRole.ecole =>
            'Mets en avant tes formations et attire les bons profils.',
        };

    final stats = <_DashboardItem>[
      if (_matchCount != null)
        _DashboardItem(
          icon: Icons.favorite_rounded,
          title: '$_matchCount',
          subtitle: 'Matches mutuels',
        ),
      if (_likesReceived != null)
        _DashboardItem(
          icon: Icons.thumb_up_alt_outlined,
          title: '$_likesReceived',
          subtitle: 'Likes recus',
        ),
      if (_unreadMessages != null)
        _DashboardItem(
          icon: Icons.mark_email_unread_rounded,
          title: '$_unreadMessages',
          subtitle: 'Messages non lus',
        ),
      if (_publishedOffers != null)
        _DashboardItem(
          icon: Icons.work_outline_rounded,
          title: '$_publishedOffers',
          subtitle: 'Offres publiées',
        ),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        // ── Hero card ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary,
                primary.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(role.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bienvenue',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          welcomeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                tagline,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _HeroChip(label: role.label, icon: Icons.verified_rounded),
                  _HeroChip(
                    label: packLevel != null && packLevel.isNotEmpty
                        ? '$packLabel · $packLevel'
                        : packLabel,
                    icon: Icons.workspace_premium_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),

        if (showCompleteBanner) ...[
          const SizedBox(height: 14),
          const _CompleteProfileBanner(),
        ],

        // ── Stats row ───────────────────────────────────────────────
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: _StatCard(item: stats[i])),
              ],
            ],
          ),
        ],

        // ── Highlights / informations clés ──────────────────────────
        const SizedBox(height: 18),
        Text(
          'Mes informations clés',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        ...highlights.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _HighlightCard(item: item),
          ),
        ),
      ],
    );
  }

  List<_DashboardItem> _buildHighlights(
      Map<String, dynamic> profile, UserRole role) {
    switch (role) {
      case UserRole.etudiant:
        return [
          _DashboardItem(
            icon: Icons.school_rounded,
            title: profile['niveauEtude']?.toString() ?? 'Niveau à compléter',
            subtitle: 'Ton niveau d’étude actuel',
          ),
          _DashboardItem(
            icon: Icons.psychology_alt_rounded,
            title: profile['domaine']?.toString() ?? 'Domaine à compléter',
            subtitle: 'Le domaine qui guide tes recommandations',
          ),
          _DashboardItem(
            icon: Icons.flag_rounded,
            title: profile['objectif']?.toString() ?? 'Objectif à préciser',
            subtitle: 'Ce que tu recherches en priorité',
          ),
        ];
      case UserRole.lyceen:
        return [
          _DashboardItem(
            icon: Icons.auto_stories_rounded,
            title:
                profile['classeActuelle']?.toString() ?? 'Classe à compléter',
            subtitle: 'Ta situation scolaire actuelle',
          ),
          _DashboardItem(
            icon: Icons.explore_rounded,
            title:
                profile['orientationSouhaitee']?.toString() ??
                'Orientation à préciser',
            subtitle: 'Le parcours qui t’attire le plus',
          ),
          _DashboardItem(
            icon: Icons.track_changes_rounded,
            title:
                profile['objectifPostbac']?.toString() ??
                'Projet post-bac à compléter',
            subtitle: 'Ton objectif après le lycée',
          ),
        ];
      case UserRole.entreprise:
        return [
          _DashboardItem(
            icon: Icons.apartment_rounded,
            title:
                profile['secteurEntreprise']?.toString() ??
                'Secteur à compléter',
            subtitle: 'Le secteur de ton entreprise',
          ),
          _DashboardItem(
            icon: Icons.groups_rounded,
            title:
                profile['tailleEntreprise']?.toString() ?? 'Taille à compléter',
            subtitle: 'La taille de structure visée par REZO',
          ),
          _DashboardItem(
            icon: Icons.campaign_rounded,
            title:
                profile['besoinsRecrutement']?.toString() ??
                'Besoins à préciser',
            subtitle: 'Les recrutements prioritaires à préparer',
          ),
        ];
      case UserRole.ecole:
        return [
          _DashboardItem(
            icon: Icons.account_balance_rounded,
            title: profile['nomEcole']?.toString() ?? 'Nom à compléter',
            subtitle: 'Nom de l’établissement',
          ),
          _DashboardItem(
            icon: Icons.menu_book_rounded,
            title: profile['filieres']?.toString() ?? 'Filières à renseigner',
            subtitle: 'Les filières mises en avant',
          ),
          _DashboardItem(
            icon: Icons.workspace_premium_rounded,
            title: profile['diplomes']?.toString() ?? 'Diplômes à renseigner',
            subtitle: 'Les diplômes délivrés',
          ),
        ];
    }
  }
}


class _CompleteProfileBanner extends StatelessWidget {
  const _CompleteProfileBanner();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // Aller au Profil quel que soit son index
        final shell =
            context.findAncestorStateOfType<_DashboardScreenState>();
        shell?.goToProfile();
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE082)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFFB8C00)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                "Complète ton profil pour de meilleures recommandations.",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
