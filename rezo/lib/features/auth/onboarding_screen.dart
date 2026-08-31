part of 'auth_flow.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  static const _slides = [
    (
      Icons.swipe_rounded,
      'Matchez plus vite',
      'Découvrez stages, alternances et opportunités pertinentes selon votre profil.',
    ),
    (
      Icons.forum_rounded,
      'Discutez au bon moment',
      'Messagerie intégrée, feedback en temps réel et parcours sans friction.',
    ),
    (
      Icons.psychology_rounded,
      'Bénéficiez de l’IA',
      'Orientation, recommandations de packs et accompagnement personnalisé.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _slides.length - 1;

    return AuthScaffold(
      title: 'Onboarding',
      subtitle: 'En quelques écrans, découvrez la promesse REZO.',
      child: Column(
        children: [
          SizedBox(
            height: 360,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (value) => setState(() => _index = value),
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        Theme.of(context).colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0xFFD0D0D0)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Étape ${index + 1}/${_slides.length}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            slide.$1,
                            size: 56,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          slide.$2,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          slide.$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _slides.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _index == index ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _index == index
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              if (isLast) {
                Navigator.of(context).pushReplacementNamed(AppRoutes.signup);
                return;
              }

              await _controller.nextPage(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
              );
            },
            child: Text(isLast ? 'Commencer' : 'Suivant'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
            },
            child: const Text('Passer'),
          ),
        ],
      ),
    );
  }
}
