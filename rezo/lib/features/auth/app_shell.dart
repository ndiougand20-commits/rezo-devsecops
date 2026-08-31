part of 'auth_flow.dart';

class RezoApp extends StatefulWidget {
  const RezoApp({super.key, this.authService, this.tokenStorage});

  final AuthService? authService;
  final TokenStorage? tokenStorage;

  @override
  State<RezoApp> createState() => _RezoAppState();
}

class _RezoAppState extends State<RezoApp> {
  late final AppState _appState;

  @override
  void initState() {
    super.initState();
    final tokenStorage = widget.tokenStorage ?? const SecureTokenStorage();
    _appState = AppState(
      authService:
          widget.authService ??
          HttpAuthService(
            baseUrl: HttpAuthService.defaultBaseUrl,
            tokenStorage: tokenStorage,
          ),
      tokenStorage: tokenStorage,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _appState,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'REZO',
        theme: ThemeData(
          colorScheme: const ColorScheme(
            brightness: Brightness.light,
            primary: Colors.black,
            onPrimary: Colors.white,
            primaryContainer: Color(0xFFE0E0E0),
            onPrimaryContainer: Colors.black,
            secondary: Color(0xFF424242),
            onSecondary: Colors.white,
            secondaryContainer: Color(0xFFE0E0E0),
            onSecondaryContainer: Colors.black,
            tertiary: Color(0xFF616161),
            onTertiary: Colors.white,
            tertiaryContainer: Color(0xFFEEEEEE),
            onTertiaryContainer: Colors.black,
            error: Colors.redAccent,
            onError: Colors.white,
            errorContainer: Color(0xFFFFDAD6),
            onErrorContainer: Color(0xFF410002),
            surface: Colors.white,
            onSurface: Colors.black,
            surfaceContainerHighest: Color(0xFFF5F5F5),
            onSurfaceVariant: Color(0xFF424242),
            outline: Color(0xFFBDBDBD),
            outlineVariant: Color(0xFFE0E0E0),
            inverseSurface: Color(0xFF303030),
            onInverseSurface: Colors.white,
            inversePrimary: Color(0xFFBDBDBD),
            surfaceTint: Colors.transparent,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            iconTheme: IconThemeData(color: Colors.black),
            actionsIconTheme: IconThemeData(color: Colors.black),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            height: 64,
            indicatorColor: Colors.black,
            indicatorShape: const StadiumBorder(),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(color: Colors.white, size: 22);
              }
              return const IconThemeData(color: Color(0xFFAAAAAA), size: 22);
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                  letterSpacing: 0.1,
                );
              }
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: Color(0xFFAAAAAA),
                letterSpacing: 0.1,
              );
            }),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F5F5),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Colors.black,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            margin: EdgeInsets.zero,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: Color(0xFFBDBDBD)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.black,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
          ),
        ),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case AppRoutes.splash:
              return MaterialPageRoute(builder: (_) => const SplashScreen());
            case AppRoutes.roleChoice:
              return MaterialPageRoute(builder: (_) => const RoleChoiceScreen());
            case AppRoutes.welcome:
              return MaterialPageRoute(
                builder: (_) => WelcomeScreen(
                  selectedRole:
                      settings.arguments as UserRole? ?? UserRole.etudiant,
                ),
              );
            case AppRoutes.onboarding:
              return MaterialPageRoute(
                builder: (_) => const OnboardingScreen(),
              );
            case AppRoutes.login:
              final args = settings.arguments;
              final loginArgs = args is LoginRouteArgs
                  ? args
                  : LoginRouteArgs(
                      initialEmail: args as String?,
                      selectedRole: null,
                    );
              return MaterialPageRoute(
                builder: (_) =>
                    LoginScreen(
                      initialEmail: loginArgs.initialEmail,
                      selectedRole: loginArgs.selectedRole,
                    ),
              );
            case AppRoutes.signup:
              return MaterialPageRoute(
                builder: (_) => SignupScreen(
                  initialRole:
                      settings.arguments as UserRole? ?? UserRole.etudiant,
                ),
              );
            case AppRoutes.dashboard:
              if (!_appState.isAuthenticated) {
                return MaterialPageRoute(builder: (_) => const LoginScreen());
              }
              return MaterialPageRoute(builder: (_) => const DashboardScreen());
            default:
              return MaterialPageRoute(builder: (_) => const RoleChoiceScreen());
          }
        },
      ),
    );
  }
}
