part of 'auth_flow.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, required this.initialRole});

  final UserRole initialRole;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  late UserRole _selectedRole;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
  final TextEditingController _nomController = TextEditingController();
  final TextEditingController _telephoneController = TextEditingController();

  final TextEditingController _niveauEtudeController = TextEditingController();
  final TextEditingController _domaineController = TextEditingController();
  final TextEditingController _competencesController = TextEditingController();
  final TextEditingController _objectifController = TextEditingController();
  final TextEditingController _experiencesController = TextEditingController();
    final TextEditingController _preferencesSecteurController =
      TextEditingController();
    final TextEditingController _preferencesLieuController =
      TextEditingController();

  final TextEditingController _classeActuelleController =
      TextEditingController();
  final TextEditingController _serieOrientationController =
      TextEditingController();
  final TextEditingController _objectifPostbacController =
      TextEditingController();
  final TextEditingController _centresInteretController =
      TextEditingController();

  final TextEditingController _raisonSocialeController =
      TextEditingController();
  final TextEditingController _secteurController = TextEditingController();
  final TextEditingController _descriptionEntrepriseController =
      TextEditingController();
  final TextEditingController _adresseEntrepriseController =
      TextEditingController();
  final TextEditingController _siteEntrepriseController =
      TextEditingController();
    final TextEditingController _logoEntrepriseController =
      TextEditingController();
  String _tailleEntreprise = 'PME';

  final TextEditingController _nomEtablissementController =
      TextEditingController();
  final TextEditingController _domainesController = TextEditingController();
  final TextEditingController _diplomesController = TextEditingController();
  final TextEditingController _descriptionEcoleController =
      TextEditingController();
  final TextEditingController _adresseEcoleController = TextEditingController();
  final TextEditingController _siteEcoleController = TextEditingController();
  final TextEditingController _logoEcoleController = TextEditingController();
  String _statutEcole = 'PRIVE';

  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    for (final controller in [
      _emailController,
      _passwordController,
      _prenomController,
      _nomController,
      _telephoneController,
      _niveauEtudeController,
      _domaineController,
      _competencesController,
      _objectifController,
      _experiencesController,
      _preferencesSecteurController,
      _preferencesLieuController,
      _classeActuelleController,
      _serieOrientationController,
      _objectifPostbacController,
      _centresInteretController,
      _raisonSocialeController,
      _secteurController,
      _descriptionEntrepriseController,
      _adresseEntrepriseController,
      _siteEntrepriseController,
      _logoEntrepriseController,
      _nomEtablissementController,
      _domainesController,
      _diplomesController,
      _descriptionEcoleController,
      _adresseEcoleController,
      _siteEcoleController,
      _logoEcoleController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);
    try {
      await AppScope.of(context).signup(_buildPayload());
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inscription réussie, connecte-toi.')),
      );
      Navigator.of(context).pushReplacementNamed(
        AppRoutes.login,
        arguments: LoginRouteArgs(
          initialEmail: _emailController.text.trim(),
          selectedRole: _selectedRole,
        ),
      );
    } on AuthException catch (error) {
      _showError(error.message);
    } catch (_) {
      _showError('Impossible de créer le compte pour le moment');
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

  Map<String, dynamic> _buildPayload() {
    final payload = <String, dynamic>{
      'email': _emailController.text.trim(),
      'password': _passwordController.text.trim(),
      'role': _selectedRole.apiValue,
      'prenom': _prenomController.text.trim(),
      'nom': _nomController.text.trim(),
      'telephone': _telephoneController.text.trim(),
      'profil': switch (_selectedRole) {
        UserRole.etudiant => {
          'niveauEtude': _niveauEtudeController.text.trim(),
          'domaine': _domaineController.text.trim(),
          if (_splitList(_competencesController.text).isNotEmpty)
            'competences': _splitList(_competencesController.text),
          if (_objectifController.text.trim().isNotEmpty)
            'objectif': _objectifController.text.trim(),
          if (_splitList(_preferencesSecteurController.text).isNotEmpty)
            'preferencesSecteur': _splitList(_preferencesSecteurController.text),
          if (_splitList(_preferencesLieuController.text).isNotEmpty)
            'preferencesLieu': _splitList(_preferencesLieuController.text),
          if (_splitList(_experiencesController.text).isNotEmpty)
            'experiences': _splitList(_experiencesController.text),
        },
        UserRole.lyceen => {
          'classeActuelle': _classeActuelleController.text.trim(),
          'serieOrientation': _serieOrientationController.text.trim(),
          'objectifPostbac': _objectifPostbacController.text.trim(),
          if (_splitList(_centresInteretController.text).isNotEmpty)
            'centresInteret': _splitList(_centresInteretController.text),
        },
        UserRole.entreprise => {
          'raisonSociale': _raisonSocialeController.text.trim(),
          'secteurActivite': _secteurController.text.trim(),
          'taille': _tailleEntreprise,
          'description': _descriptionEntrepriseController.text.trim(),
          if (_adresseEntrepriseController.text.trim().isNotEmpty)
            'adresse': _adresseEntrepriseController.text.trim(),
          if (_siteEntrepriseController.text.trim().isNotEmpty)
            'siteWeb': _siteEntrepriseController.text.trim(),
          if (_logoEntrepriseController.text.trim().isNotEmpty)
            'logoUrl': _logoEntrepriseController.text.trim(),
        },
        UserRole.ecole => {
          'nomEtablissement': _nomEtablissementController.text.trim(),
          'statut': _statutEcole,
          if (_splitList(_domainesController.text).isNotEmpty)
            'domaines': _splitList(_domainesController.text),
          if (_splitList(_diplomesController.text).isNotEmpty)
            'diplomesDelivres': _splitList(_diplomesController.text),
          if (_descriptionEcoleController.text.trim().isNotEmpty)
            'description': _descriptionEcoleController.text.trim(),
          if (_adresseEcoleController.text.trim().isNotEmpty)
            'adresse': _adresseEcoleController.text.trim(),
          if (_siteEcoleController.text.trim().isNotEmpty)
            'siteWeb': _siteEcoleController.text.trim(),
          if (_logoEcoleController.text.trim().isNotEmpty)
            'logoUrl': _logoEcoleController.text.trim(),
        },
      },
    };

    payload.removeWhere((key, value) =>
        value is String && value.trim().isEmpty);
    return payload;
  }

  List<String> _splitList(String value) {
    return value
        .split(',')
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: false,
      title: 'Créer un compte ${_selectedRole.label}',
      subtitle: 'Choisis ton rôle puis complète le formulaire adapté.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _AuthSectionTitle(
              title: 'Choisis ton espace',
              subtitle: 'Sélectionne ton rôle pour afficher le bon formulaire.',
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              _InfoBanner(
                message: _errorMessage!,
                color: Colors.red.shade50,
                textColor: Colors.red.shade800,
              ),
              const SizedBox(height: 12),
            ],
            _RoleSelector(
              selectedRole: _selectedRole,
              onChanged: (value) {
                setState(() => _selectedRole = value);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _prenomController,
              decoration: const InputDecoration(labelText: 'Prénom contact'),
              validator: (value) => _requiredField(value, 'Le prénom'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nomController,
              decoration: const InputDecoration(labelText: 'Nom contact'),
              validator: (value) => _requiredField(value, 'Le nom'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _telephoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              validator: _optionalPhoneValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Adresse e-mail'),
              validator: _validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Mot de passe'),
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            _RoleBenefitCard(role: _selectedRole),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildRoleSpecificSection(),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Créer mon compte'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed(
                  AppRoutes.login,
                  arguments: LoginRouteArgs(selectedRole: _selectedRole),
                );
              },
              child: const Text('J’ai déjà un compte'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSpecificSection() {
    switch (_selectedRole) {
      case UserRole.etudiant:
        return Column(
          key: const ValueKey('student-section'),
          children: [
            TextFormField(
              controller: _niveauEtudeController,
              decoration: const InputDecoration(labelText: 'Niveau d’étude'),
              validator: (value) => _requiredField(value, 'Le niveau d’étude'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _domaineController,
              decoration: const InputDecoration(labelText: 'Domaine'),
              validator: (value) => _requiredField(value, 'Le domaine'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _competencesController,
              decoration: const InputDecoration(
                labelText: 'Compétences (séparées par des virgules)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _objectifController,
              decoration: const InputDecoration(labelText: 'Objectif'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _experiencesController,
              decoration: const InputDecoration(
                labelText: 'Expériences (séparées par des virgules)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _preferencesSecteurController,
              decoration: const InputDecoration(
                labelText: 'Préférences secteur (séparées par des virgules)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _preferencesLieuController,
              decoration: const InputDecoration(
                labelText: 'Préférences lieu (séparées par des virgules)',
              ),
            ),
          ],
        );
      case UserRole.lyceen:
        return Column(
          key: const ValueKey('high-school-section'),
          children: [
            TextFormField(
              controller: _classeActuelleController,
              decoration: const InputDecoration(labelText: 'Classe actuelle'),
              validator: (value) => _requiredField(value, 'La classe actuelle'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _serieOrientationController,
              decoration: const InputDecoration(
                labelText: 'Série / orientation',
              ),
              validator: (value) =>
                  _requiredField(value, 'La série ou orientation'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _objectifPostbacController,
              decoration: const InputDecoration(labelText: 'Objectif post-bac'),
              validator: (value) =>
                  _requiredField(value, 'L\'objectif post-bac'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _centresInteretController,
              decoration: const InputDecoration(
                labelText: 'Centres d’intérêt (séparés par des virgules)',
              ),
            ),
          ],
        );
      case UserRole.entreprise:
        return Column(
          key: const ValueKey('company-section'),
          children: [
            TextFormField(
              controller: _raisonSocialeController,
              decoration: const InputDecoration(labelText: 'Nom entreprise'),
              validator: (value) => _requiredField(value, 'Le nom entreprise'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _secteurController,
              decoration: const InputDecoration(labelText: 'Secteur'),
              validator: (value) => _requiredField(value, 'Le secteur'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _tailleEntreprise,
              decoration: const InputDecoration(labelText: 'Taille'),
              items: const [
                DropdownMenuItem(value: 'MICRO', child: Text('MICRO')),
                DropdownMenuItem(value: 'PME', child: Text('PME')),
                DropdownMenuItem(value: 'ETI', child: Text('ETI')),
                DropdownMenuItem(value: 'GE', child: Text('GE')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _tailleEntreprise = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionEntrepriseController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
              validator: (value) => _requiredField(value, 'La description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adresseEntrepriseController,
              decoration: const InputDecoration(labelText: 'Adresse'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _siteEntrepriseController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Site web'),
              validator: _optionalUrlValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _logoEntrepriseController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL logo'),
              validator: _optionalUrlValidator,
            ),
          ],
        );
      case UserRole.ecole:
        return Column(
          key: const ValueKey('school-section'),
          children: [
            TextFormField(
              controller: _nomEtablissementController,
              decoration: const InputDecoration(labelText: 'Nom établissement'),
              validator: (value) =>
                  _requiredField(value, 'Le nom établissement'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _statutEcole,
              decoration: const InputDecoration(labelText: 'Statut'),
              items: const [
                DropdownMenuItem(value: 'PUBLIC', child: Text('PUBLIC')),
                DropdownMenuItem(value: 'PRIVE', child: Text('PRIVE')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _statutEcole = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _domainesController,
              decoration: const InputDecoration(
                labelText: 'Domaines (séparés par des virgules)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _diplomesController,
              decoration: const InputDecoration(
                labelText: 'Diplômes délivrés (séparés par des virgules)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionEcoleController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _adresseEcoleController,
              decoration: const InputDecoration(labelText: 'Adresse'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _siteEcoleController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Site web'),
              validator: _optionalUrlValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _logoEcoleController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL logo'),
              validator: _optionalUrlValidator,
            ),
          ],
        );
    }
  }
}
