part of 'auth_flow.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  /// Liste des onglets visibles, calculée à chaque build selon le rôle
  /// et les permissions de l'utilisateur courant.
  late List<_TabSpec> _visibleTabs;

  void goToTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index.clamp(0, _visibleTabs.length - 1));
  }

  /// Ouvre la page profil via l'icône en haut.
  void goToProfile() {
    if (!mounted) return;
    final appState = AppScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Profil')),
          body: SafeArea(
            child: _ProfileTab(
              onLogout: () async {
                await appState.logout();
                if (!mounted) return;
                Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.roleChoice,
                  (route) => false,
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.currentUser ?? <String, dynamic>{};
    final role = parseUserRole(user['role'] as String?);
    final fullName = [
      user['prenom'],
      user['nom'],
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' ');

    _visibleTabs = _buildTabs(
      appState: appState,
      user: user,
      role: role,
      fullName: fullName,
    );

    if (_currentIndex >= _visibleTabs.length) {
      _currentIndex = 0;
    }

    final current = _visibleTabs[_currentIndex];

    // Initiales pour l'avatar de profil
    final initials = () {
      final parts = fullName.trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P';
    }();

    final avatarUrl = user['avatarUrl']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        toolbarHeight: 60,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFF0F0F0)),
        ),
        title: Row(
          children: [
            const Text(
              'REZO',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 19,
                letterSpacing: -0.5,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              current.title,
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 15,
                color: Color(0xFFAAAAAA),
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: goToProfile,
            child: Tooltip(
              message: 'Mon profil',
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
                clipBehavior: Clip.antiAlias,
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(current.kind),
            child: current.widget,
          ),
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 1, color: const Color(0xFFF0F0F0)),
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: _visibleTabs
                .map(
                  (t) => NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  List<_TabSpec> _buildTabs({
    required AppState appState,
    required Map<String, dynamic> user,
    required UserRole role,
    required String fullName,
  }) {
    final canViewMatching = _canUseFeature(
      user: user,
      directKeys: const ['canViewOpportunities', 'canUseMatching'],
      packFlags: const ['MATCHING_BASIC', 'MATCHING_ADVANCED', 'MATCHING_PREMIUM'],
      fallback: true,
    );
    final canUseMessaging = _canUseFeature(
      user: user,
      directKeys: const ['canUseMessaging'],
      packFlags: const ['MESSAGERIE_LIMITEE', 'MESSAGERIE_ILLIMITEE'],
      fallback: true,
    );
    final canManageOffers = _canUseFeature(
      user: user,
      directKeys: const ['canManageOffers'],
      packFlags: const ['OFFERS_PUBLISH'],
      fallback: role == UserRole.ecole || role == UserRole.entreprise,
    );
    final canUseAiChat = _canUseFeature(
      user: user,
      directKeys: const ['canUseAiChat'],
      packFlags: const ['AI_CHAT_ACCESS'],
      fallback: false,
    );

    final tabs = <_TabSpec>[
      _TabSpec(
        kind: _TabKind.report,
        title: 'Rapport',
        label: 'Rapport',
        icon: Icons.insights_outlined,
        selectedIcon: Icons.insights_rounded,
        widget: _ReportTab(role: role, key: PageStorageKey('report_tab')),
      ),
    ];

    if (canViewMatching) {
      tabs.insert(
        0,
        const _TabSpec(
          kind: _TabKind.matching,
          title: 'Matching',
          label: 'Matching',
          icon: Icons.swipe_outlined,
          selectedIcon: Icons.swipe_rounded,
          widget: _MatchesTab(key: PageStorageKey('matching_tab')),
        ),
      );
    }

    if (canUseMessaging) {
      tabs.add(
        const _TabSpec(
          kind: _TabKind.messages,
          title: 'Messages',
          label: 'Messages',
          icon: Icons.forum_outlined,
          selectedIcon: Icons.forum_rounded,
          widget: _MessagesTab(key: PageStorageKey('messages_tab')),
        ),
      );
    }

    if ((role == UserRole.ecole || role == UserRole.entreprise) &&
        canManageOffers) {
      tabs.add(_TabSpec(
        kind: _TabKind.offers,
        title: 'Mes offres',
        label: 'Offres',
        icon: Icons.work_outline_rounded,
        selectedIcon: Icons.work_rounded,
        widget: const _OffersTab(key: PageStorageKey('offers_tab')),
      ));
    }

    if (canUseAiChat) {
      tabs.add(const _TabSpec(
        kind: _TabKind.aiChat,
        title: 'Chat IA',
        label: 'IA',
        icon: Icons.smart_toy_outlined,
        selectedIcon: Icons.smart_toy_rounded,
        widget: _AiChatTab(key: PageStorageKey('aichat_tab')),
      ));
    }

    return tabs;
  }

  bool _canUseFeature({
    required Map<String, dynamic> user,
    required List<String> directKeys,
    required List<String> packFlags,
    required bool fallback,
  }) {
    for (final key in directKeys) {
      final raw = user[key];
      if (raw is bool) return raw;
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized == 'true') return true;
        if (normalized == 'false') return false;
      }
      if (raw is num) return raw != 0;
    }

    final features = _packFeatures(user);
    if (features.isNotEmpty) {
      for (final flag in packFlags) {
        if (features.contains(flag)) return true;
      }
      return false;
    }

    return fallback;
  }

  Set<String> _packFeatures(Map<String, dynamic> user) {
    final raw = user['packFeatures'];
    if (raw is List) {
      return raw
          .map((item) => item.toString().trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toSet();
    }
    return <String>{};
  }
}

enum _TabKind { messages, matching, offers, aiChat, report }

class _TabSpec {
  const _TabSpec({
    required this.kind,
    required this.title,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.widget,
  });

  final _TabKind kind;
  final String title;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget widget;
}
