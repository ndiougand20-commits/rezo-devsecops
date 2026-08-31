part of 'auth_flow.dart';

class _FeaturePlaceholderCard extends StatelessWidget {
  const _FeaturePlaceholderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RezoLogo extends StatelessWidget {
  const RezoLogo({super.key, this.height = 96, this.withBackground = true});

  final double height;
  final bool withBackground;

  @override
  Widget build(BuildContext context) {
    final content = Image.asset(
      'assets/REZO_Logo.png',
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.hub_rounded,
        size: height * 0.55,
        color: Theme.of(context).colorScheme.primary,
      ),
    );

    if (!withBackground) {
      return content;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: content,
    );
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBackButton = true,
    this.centerHeaderText = false,
    this.headerTopSpacing = 6,
    this.bodyTopSpacing = 16,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBackButton;
  final bool centerHeaderText;
  final double headerTopSpacing;
  final double bodyTopSpacing;

  @override
  Widget build(BuildContext context) {
    final canPop = showBackButton && Navigator.of(context).canPop();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF0F0F0), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF000000).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            top: 110,
            left: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF7B8CFF).withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (canPop)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE0E0E0)),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    SizedBox(height: headerTopSpacing),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: centerHeaderText
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            textAlign: centerHeaderText
                                ? TextAlign.center
                                : TextAlign.start,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            textAlign: centerHeaderText
                                ? TextAlign.center
                                : TextAlign.start,
                            style: const TextStyle(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: bodyTopSpacing),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthSectionTitle extends StatelessWidget {
  const _AuthSectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade700, height: 1.3),
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.selectedRole, required this.onChanged});

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vous êtes', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: UserRole.values.map((role) {
            final isSelected = role == selectedRole;
            return ChoiceChip(
              selected: isSelected,
              showCheckmark: false,
              avatar: Icon(
                role.icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.primary,
              ),
              label: Text(role.label),
              labelStyle: TextStyle(
                color: isSelected
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              backgroundColor: Colors.white,
              selectedColor: Theme.of(context).colorScheme.primary,
              side: const BorderSide(color: Color(0xFFD7E3FF)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              onSelected: (_) => onChanged(role),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _RoleBenefitCard extends StatelessWidget {
  const _RoleBenefitCard({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondaryContainer,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              role.icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role.label,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(role.benefit, style: const TextStyle(height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
    required this.color,
    required this.textColor,
  });

  final String message;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: textColor)),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD0D0D0)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

/// Construit une vue profil cohérente même si le backend renvoie des noms de
/// champs différents selon les rôles / versions de payload.
Map<String, dynamic> resolveUserProfile(Map<String, dynamic> user) {
  final merged = <String, dynamic>{};

  void mergeCandidate(dynamic candidate) {
    if (candidate is! Map) return;
    final map = candidate.cast<String, dynamic>();
    map.forEach((key, value) {
      if (!_hasValue(merged[key]) && _hasValue(value)) {
        merged[key] = value;
      }
    });
  }

  mergeCandidate(user['profil']);
  mergeCandidate(user['profile']);
  mergeCandidate(user['profileData']);
  mergeCandidate(user['detailsProfil']);

  for (final key in const [
    'niveauEtude',
    'domaine',
    'competences',
    'objectif',
    'experiences',
    'preferencesSecteur',
    'preferencesLieu',
    'classeActuelle',
    'orientationSouhaitee',
    'serieOrientation',
    'objectifPostbac',
    'centresInteret',
    'secteurActivite',
    'taille',
    'description',
    'siteWeb',
    'adresse',
    'nomEtablissement',
    'domaines',
    'diplomesDelivres',
    'nomEcole',
    'filieres',
    'diplomes',
    'secteurEntreprise',
    'tailleEntreprise',
    'besoinsRecrutement',
    'descriptionEntreprise',
  ]) {
    if (!_hasValue(merged[key]) && _hasValue(user[key])) {
      merged[key] = user[key];
    }
  }

  void alias(String canonical, List<String> aliases) {
    if (_hasValue(merged[canonical])) return;
    for (final key in aliases) {
      if (_hasValue(merged[key])) {
        merged[canonical] = merged[key];
        return;
      }
    }
  }

  alias('orientationSouhaitee', const ['serieOrientation']);
  alias('secteurActivite', const ['domaine']);
  alias('secteurEntreprise', const ['secteurActivite']);
  alias('tailleEntreprise', const ['taille']);
  alias('descriptionEntreprise', const ['description']);
  alias('nomEcole', const ['nomEtablissement']);
  alias('filieres', const ['domaines']);
  alias('diplomes', const ['diplomesDelivres']);
  alias('besoinsRecrutement', const ['besoins', 'description']);

  return merged;
}

bool _hasValue(dynamic value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is List || value is Map) return value.isNotEmpty;
  return true;
}

// === Helpers globaux (G12) ============================================

/// Helper unifié pour gérer les erreurs d'authentification (401) et réseau.
/// - 401 : déconnecte et renvoie vers la page d'accueil.
/// - "Pas de connexion internet" : SnackBar rouge.
/// - Autres : SnackBar avec le message d'erreur.
void handleAuthError(BuildContext context, AuthException e) {
  if (!context.mounted) return;
  if (e.statusCode == 401) {
    final appState = AppScope.of(context);
    unawaited(appState.logout());
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.welcome,
      (route) => false,
    );
    return;
  }
  final isNetwork = e.message.toLowerCase().contains('connexion');
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(e.message),
      backgroundColor: isNetwork ? Colors.red.shade700 : null,
    ),
  );
}

/// Formatte une date en français court : "12 mars 2025".
String formatDate(DateTime date, {bool withTime = false}) {
  const mois = [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ];
  final m = mois[(date.month - 1).clamp(0, 11)];
  final base = '${date.day} $m ${date.year}';
  if (!withTime) return base;
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  return '$base, $hh:$mm';
}

/// Formatte une date relative ("il y a 5 min", "hier", "12 mars").
String formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 60) return "à l'instant";
  if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  if (diff.inDays == 1) return 'hier';
  if (diff.inDays < 7) return 'il y a ${diff.inDays} j';
  return formatDate(date);
}

/// Skeleton loader léger (sans dépendre de la lib `shimmer`).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 6,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) {
        final t = _ctrl.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              const Color(0xFFEDEDED),
              const Color(0xFFDDDDDD),
              t,
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 5});
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SkeletonBox(width: 180, height: 14),
            SizedBox(height: 8),
            SkeletonBox(width: double.infinity, height: 12),
            SizedBox(height: 6),
            SkeletonBox(width: 220, height: 12),
          ],
        ),
      ),
    );
  }
}
