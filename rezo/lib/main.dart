import 'package:flutter/material.dart';

import 'features/auth/auth_flow.dart'
    show
        RezoApp,
        AuthService,
        TokenStorage,
        FakeAuthService,
        MemoryTokenStorage,
        HttpAuthService,
        SecureTokenStorage;

const _useFakeAuth = bool.fromEnvironment('USE_FAKE_AUTH', defaultValue: false);

final _tokenStorage = _useFakeAuth
    ? MemoryTokenStorage()
    : const SecureTokenStorage();
final _authService = _useFakeAuth
    ? FakeAuthService()
    : HttpAuthService(
        baseUrl: HttpAuthService.defaultBaseUrl,
        tokenStorage: _tokenStorage,
      );

void main() {
  runApp(MyApp(authService: _authService, tokenStorage: _tokenStorage));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.authService, this.tokenStorage});

  final AuthService? authService;
  final TokenStorage? tokenStorage;

  @override
  Widget build(BuildContext context) {
    return RezoApp(authService: authService, tokenStorage: tokenStorage);
  }
}
