part of 'auth_flow.dart';

class RoleChoiceScreen extends StatefulWidget {
  const RoleChoiceScreen({super.key});

  @override
  State<RoleChoiceScreen> createState() => _RoleChoiceScreenState();
}

class _RoleChoiceScreenState extends State<RoleChoiceScreen> {
  UserRole _selectedRole = UserRole.etudiant;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Choisis ton profil',
        subtitle: 'Choisis et continue.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 270,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: -0.14,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7F7),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE4E4E4)),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: 0.1,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFE4E4E4)),
                    ),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFFFFF), Color(0xFFF0F0F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFDADADA)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _SwipeBadge(
                            label: 'LIKE',
                            color: Colors.black,
                          ),
                          _SwipeBadge(
                            label: 'NOPE',
                            color: const Color(0xFF616161),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFD4D4D4)),
                        ),
                        child: Icon(_selectedRole.icon, size: 34),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedRole.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 14,
              runSpacing: 14,
            children: UserRole.values
                .map(
                  (role) => _RoleChoiceTile(
                    role: role,
                    selected: role == _selectedRole,
                    onTap: () => setState(() => _selectedRole = role),
                  ),
                )
                .toList(),
          ),
            const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(
                AppRoutes.welcome,
                arguments: _selectedRole,
              );
            },
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Continuer'),
          ),
        ],
      ),
    );
  }
}

class _RoleChoiceTile extends StatelessWidget {
  const _RoleChoiceTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? const Color(0xFF111111) : Colors.white,
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF111111)
                        : const Color(0xFFD8D8D8),
                    width: selected ? 2.4 : 1.4,
                  ),
                ),
                child: Icon(
                  role.icon,
                  size: 28,
                  color: selected ? Colors.white : Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            role.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _SwipeBadge extends StatelessWidget {
  const _SwipeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: label == 'LIKE' ? -0.15 : 0.15,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
