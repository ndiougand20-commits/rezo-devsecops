part of 'auth_flow.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.selectedRole = UserRole.etudiant});

  final UserRole selectedRole;

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Bienvenue ${selectedRole.label}',
      subtitle: 'Un accès simple à votre réseau d’opportunités.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          const Center(
            child: RezoLogo(height: 112, withBackground: false),
          ),
          const SizedBox(height: 28),
          const Text(
            'Le bon contact, au bon moment.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Étudiants, lycéens, entreprises et écoles dans une expérience simple, nette et directe.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            height: 1,
            color: const Color(0xFFE6E6E6),
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamed(
                AppRoutes.login,
                arguments: LoginRouteArgs(selectedRole: selectedRole),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            child: const Text('Se connecter'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushNamed(AppRoutes.signup, arguments: selectedRole);
            },
            child: const Text('Créer un compte'),
          ),

        ],
      ),
    );
  }
}
