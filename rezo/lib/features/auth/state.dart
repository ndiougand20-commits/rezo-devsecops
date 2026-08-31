part of 'auth_flow.dart';

class AppState extends ChangeNotifier {
  AppState({
    required AuthService authService,
    required TokenStorage tokenStorage,
  }) : _authService = authService,
       _tokenStorage = tokenStorage;

  final AuthService _authService;
  final TokenStorage _tokenStorage;

  bool _isAuthenticated = false;
  bool _isCheckingSession = false;
  String? _token;
  Map<String, dynamic>? _currentUser;

  bool get isAuthenticated => _isAuthenticated;
  bool get isCheckingSession => _isCheckingSession;
  String? get token => _token;
  Map<String, dynamic>? get currentUser => _currentUser;
  UserRole get currentRole => parseUserRole(_currentUser?['role'] as String?);

  Future<bool> restoreSession() async {
    _isCheckingSession = true;
    notifyListeners();

    try {
      final savedToken = await _tokenStorage.readToken();
      if (savedToken == null || savedToken.isEmpty) {
        _reset();
        return false;
      }

      final me = await _authService.getMe();
      _token = savedToken;
      _currentUser = me;
      _isAuthenticated = true;
      return true;
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      _reset();
      return false;
    } catch (_) {
      await _tokenStorage.clearToken();
      _reset();
      return false;
    } finally {
      _isCheckingSession = false;
      notifyListeners();
    }
  }

  Future<void> signup(Map<String, dynamic> payload) {
    return _authService.signup(payload);
  }

  Future<void> login({required String email, required String password}) async {
    final jwt = await _authService.login(email: email, password: password);
    await _tokenStorage.saveToken(jwt);
    try {
      final me = await _authService.getMe();

      _token = jwt;
      _currentUser = me;
      _isAuthenticated = true;
      notifyListeners();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _tokenStorage.readRefreshToken();
      await _authService.logout(refreshToken: refreshToken);
    } catch (_) {
      await _tokenStorage.clearToken();
    }
    _reset();
    notifyListeners();
  }

  Future<Map<String, dynamic>> refreshCurrentUser() async {
    try {
      final me = await _authService.getMe();
      _currentUser = me;
      _isAuthenticated = true;
      notifyListeners();
      return me;
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> payload,
  ) async {
    try {
      await _authService.updateMe(payload);
      return refreshCurrentUser();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> changePack(String packId) async {
    try {
      await _authService.updatePack(packId);
      return refreshCurrentUser();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchPacks() async {
    try {
      return await _authService.getPacks();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMessages() async {
    try {
      return await _authService.getMessages();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchOffers() async {
    try {
      return await _authService.getOffers();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      return _authService.uploadProfilePhoto(bytes: bytes, fileName: fileName);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadJustificatifPdf({
    required Uint8List bytes,
    required String fileName,
    String? category,
  }) async {
    try {
      return _authService.uploadJustificatifPdf(
        bytes: bytes,
        fileName: fileName,
        category: category,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMyMedia({String? category}) async {
    try {
      return _authService.listMyMedia(category: category);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteMyMedia(String mediaId) async {
    try {
      await _authService.deleteMyMedia(mediaId);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // Matching
  // ==========================================================

  Future<Map<String, dynamic>> fetchRecommendations({bool includeSwiped = false}) async {
    try {
      return await _authService.fetchRecommendations(
        includeSwiped: includeSwiped,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recordSwipe({
    required String offerId,
    required String action,
  }) async {
    try {
      return await _authService.recordSwipe(
        offerId: offerId,
        action: action,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchSchoolRecommendations({String? secteur}) async {
    try {
      return await _authService.fetchSchoolRecommendations(secteur: secteur);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchProfileRecommendations({
    bool includeSwiped = false,
  }) async {
    try {
      return await _authService.fetchProfileRecommendations(
        includeSwiped: includeSwiped,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> recordProfileSwipe({
    required String targetUserId,
    required String action,
  }) async {
    try {
      return await _authService.recordProfileSwipe(
        targetUserId: targetUserId,
        action: action,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchMutualMatches() async {
    try {
      return await _authService.fetchMutualMatches();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchMyStats() async {
    try {
      return await _authService.fetchMyStats();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String sessionId,
    String? context,
  }) async {
    try {
      return await _authService.sendChatMessage(
        message: message,
        sessionId: sessionId,
        context: context,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // Messagerie
  // ==========================================================

  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String content,
    String? relatedOfferId,
  }) async {
    try {
      return await _authService.sendMessage(
        receiverId: receiverId,
        content: content,
        relatedOfferId: relatedOfferId,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getConversation(String userId) async {
    try {
      return await _authService.getConversation(userId);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> markMessageRead(String messageId) async {
    try {
      return await _authService.markMessageRead(messageId);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    try {
      await _authService.deleteMessage(messageId);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // Offres CRUD
  // ==========================================================

  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> payload) async {
    try {
      return await _authService.createOffer(payload);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateOffer(
    String offerId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _authService.updateOffer(offerId, payload);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteOffer(String offerId) async {
    try {
      await _authService.deleteOffer(offerId);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> uploadOfferPdf({
    required String offerId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      return await _authService.uploadOfferPdf(
        offerId: offerId,
        bytes: bytes,
        fileName: fileName,
      );
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getOfferLikedBy(String offerId) async {
    try {
      return await _authService.getOfferLikedBy(offerId);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  // ==========================================================
  // Schools / Companies
  // ==========================================================

  Future<List<Map<String, dynamic>>> listSchools() async {
    try {
      return await _authService.listSchools();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSchool(Map<String, dynamic> payload) async {
    try {
      return await _authService.createSchool(payload);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSchool(
    String schoolId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _authService.updateSchool(schoolId, payload);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> listCompanies() async {
    try {
      return await _authService.listCompanies();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> payload) async {
    try {
      return await _authService.createCompany(payload);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCompany(
    String companyId,
    Map<String, dynamic> payload,
  ) async {
    try {
      return await _authService.updateCompany(companyId, payload);
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getFeatureAccess() async {
    try {
      return await _authService.getFeatureAccess();
    } on AuthException catch (error) {
      await _clearSessionIfUnauthorized(error);
      notifyListeners();
      rethrow;
    }
  }

  void _reset() {
    _token = null;
    _currentUser = null;
    _isAuthenticated = false;
  }

  Future<void> _clearSessionIfUnauthorized(AuthException error) async {
    if (error.statusCode == 401) {
      await _tokenStorage.clearToken();
      _reset();
    }
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({required AppState notifier, required super.child, super.key})
    : super(notifier: notifier);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope non trouvé dans le contexte.');
    return scope!.notifier!;
  }
}
