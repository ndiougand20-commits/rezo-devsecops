part of 'auth_flow.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    this.initialEmail,
    this.selectedRole,
  });

  final String? initialEmail;
  final UserRole? selectedRole;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      await AppScope.of(context).login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.dashboard, (route) => false);
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Impossible de se connecter pour le moment');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _showError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = widget.selectedRole;
    return AuthScaffold(
      title: selectedRole == null
          ? 'Connexion'
          : 'Connexion ${selectedRole.label}',
      subtitle: 'Accède à ton espace en quelques secondes.',
      showBackButton: false,
      centerHeaderText: true,
      headerTopSpacing: 40,
      bodyTopSpacing: 44,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: RezoLogo(height: 72, withBackground: false),
            ),
            const SizedBox(height: 14),
            const Text(
              'Content de te revoir.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.1,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Entre ton email et ton mot de passe pour continuer',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 14),
            if (_errorMessage != null) ...[
              _InfoBanner(
                message: _errorMessage!,
                color: Colors.red.shade50,
                textColor: Colors.red.shade800,
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Adresse e-mail',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: _validateEmail,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
              validator: _validatePassword,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Connexion'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _loading
                  ? null
                  : () {
                      Navigator.of(context).pushReplacementNamed(
                        AppRoutes.signup,
                        arguments: selectedRole ?? UserRole.etudiant,
                      );
                    },
              child: const Text('Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
