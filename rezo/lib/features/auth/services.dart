part of 'auth_flow.dart';

abstract class AuthService {
  Future<void> signup(Map<String, dynamic> payload);

  Future<String> login({required String email, required String password});

  Future<void> refreshSession();

  Future<void> logout({String? refreshToken});

  Future<Map<String, dynamic>> getMe();

  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> updatePack(String packId);

  Future<List<Map<String, dynamic>>> getPacks();

  Future<List<Map<String, dynamic>>> getMessages();

  Future<List<Map<String, dynamic>>> getOffers();

  Future<Map<String, dynamic>> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  });

  Future<Map<String, dynamic>> uploadJustificatifPdf({
    required Uint8List bytes,
    required String fileName,
    String? category,
  });

  Future<List<Map<String, dynamic>>> listMyMedia({String? category});

  Future<void> deleteMyMedia(String mediaId);

  // ---- Matching ----
  Future<Map<String, dynamic>> fetchRecommendations({bool includeSwiped = false});

  Future<Map<String, dynamic>> recordSwipe({
    required String offerId,
    required String action,
  });

  Future<Map<String, dynamic>> fetchSchoolRecommendations({String? secteur});

  Future<Map<String, dynamic>> fetchProfileRecommendations({
    bool includeSwiped = false,
  });

  Future<Map<String, dynamic>> recordProfileSwipe({
    required String targetUserId,
    required String action,
  });

  Future<List<Map<String, dynamic>>> fetchMutualMatches();

  Future<Map<String, dynamic>> fetchMyStats();

  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String sessionId,
    String? context,
  });

  // ---- Messagerie ----
  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String content,
    String? relatedOfferId,
  });

  Future<List<Map<String, dynamic>>> getConversation(String userId);

  Future<Map<String, dynamic>> markMessageRead(String messageId);

  Future<void> deleteMessage(String messageId);

  // ---- Offres CRUD ----
  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> updateOffer(
    String offerId,
    Map<String, dynamic> payload,
  );

  Future<void> deleteOffer(String offerId);

  Future<Map<String, dynamic>> uploadOfferPdf({
    required String offerId,
    required Uint8List bytes,
    required String fileName,
  });

  Future<Map<String, dynamic>> getOfferLikedBy(String offerId);

  // ---- Schools ----
  Future<List<Map<String, dynamic>>> listSchools();

  Future<Map<String, dynamic>> createSchool(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> updateSchool(
    String schoolId,
    Map<String, dynamic> payload,
  );

  // ---- Companies ----
  Future<List<Map<String, dynamic>>> listCompanies();

  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> payload);

  Future<Map<String, dynamic>> updateCompany(
    String companyId,
    Map<String, dynamic> payload,
  );

  // ---- Feature access ----
  Future<Map<String, dynamic>> getFeatureAccess();
}

class HttpAuthService implements AuthService {
  HttpAuthService({required this.baseUrl, required this.tokenStorage});

  static String get defaultBaseUrl {
    final envBaseUrl = const String.fromEnvironment(
      'REZO_API_BASE_URL',
      defaultValue: '',
    ).trim();
    if (envBaseUrl.isNotEmpty) {
      return envBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android emulator reaches host machine through 10.0.2.2
      return 'http://10.0.2.2:8080';
    }
    // Windows/macOS/Linux/iOS simulator defaults to localhost backend.
    return 'http://localhost:8080';
  }

  final String baseUrl;
  final TokenStorage tokenStorage;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: queryParameters);
  }

  // --- Wrappers réseau (G12.2) : convertissent les erreurs réseau en
  // AuthException("Pas de connexion internet") pour un affichage uniforme
  // + retry automatique sur 401 via refresh token.
  Future<http.Response> _httpGet(Uri url, {Map<String, String>? headers}) =>
      _sendWithAutoRefresh(
        headers: headers,
        sender: (effectiveHeaders) =>
            _safeNet(() => http.get(url, headers: effectiveHeaders)),
      );
  Future<http.Response> _httpPost(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _sendWithAutoRefresh(
        headers: headers,
        sender: (effectiveHeaders) => _safeNet(
          () => http.post(url, headers: effectiveHeaders, body: body),
        ),
      );
  Future<http.Response> _httpPut(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _sendWithAutoRefresh(
        headers: headers,
        sender: (effectiveHeaders) => _safeNet(
          () => http.put(url, headers: effectiveHeaders, body: body),
        ),
      );
  Future<http.Response> _httpPatch(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _sendWithAutoRefresh(
        headers: headers,
        sender: (effectiveHeaders) => _safeNet(
          () => http.patch(url, headers: effectiveHeaders, body: body),
        ),
      );
  Future<http.Response> _httpDelete(Uri url,
          {Map<String, String>? headers, Object? body}) =>
      _sendWithAutoRefresh(
        headers: headers,
        sender: (effectiveHeaders) => _safeNet(
          () => http.delete(url, headers: effectiveHeaders, body: body),
        ),
      );

  Future<http.Response> _sendWithAutoRefresh({
    required Map<String, String>? headers,
    required Future<http.Response> Function(Map<String, String>? headers) sender,
  }) async {
    final first = await sender(headers);
    if (first.statusCode != 401 || !_hasBearerToken(headers)) {
      return first;
    }

    final refreshed = await _tryRefreshTokens();
    if (!refreshed) {
      return first;
    }

    final retryHeaders = Map<String, String>.from(headers ?? const {});
    final token = await tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      retryHeaders['Authorization'] = 'Bearer $token';
    }
    return sender(retryHeaders);
  }

  bool _hasBearerToken(Map<String, String>? headers) {
    final authorization = headers?['Authorization']?.trim() ?? '';
    return authorization.toLowerCase().startsWith('bearer ');
  }

  Future<bool> _tryRefreshTokens() async {
    final refreshToken = await tokenStorage.readRefreshToken();
    if (refreshToken == null || refreshToken.trim().isEmpty) {
      await tokenStorage.clearToken();
      return false;
    }

    final response = await _safeNet(
      () async => http.post(
        _uri('/api/auth/refresh'),
        headers: await _headers(),
        body: jsonEncode({'refreshToken': refreshToken.trim()}),
      ),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      await tokenStorage.clearToken();
      return false;
    }

    final body = _decodeBody(response);
    final data = _asMap(_extractData(body));
    final accessToken =
        data['token']?.toString() ?? data['accessToken']?.toString() ?? '';
    final rotatedRefresh =
        data['refreshToken']?.toString() ?? data['newRefreshToken']?.toString() ?? '';
    if (accessToken.isEmpty) {
      await tokenStorage.clearToken();
      return false;
    }

    await tokenStorage.saveToken(accessToken);
    if (rotatedRefresh.isNotEmpty) {
      await tokenStorage.saveRefreshToken(rotatedRefresh);
    }
    return true;
  }

  Future<http.Response> _safeNet(
      Future<http.Response> Function() request) async {
    try {
      return await request();
    } on http.ClientException {
      throw const AuthException('Pas de connexion internet');
    } on FormatException {
      rethrow;
    } catch (e) {
      // Erreurs réseau bas-niveau (SocketException, HandshakeException…)
      // On évite d'importer dart:io pour rester compatible web.
      final msg = e.toString().toLowerCase();
      if (msg.contains('socket') ||
          msg.contains('failed host lookup') ||
          msg.contains('connection') ||
          msg.contains('handshake')) {
        throw const AuthException('Pas de connexion internet');
      }
      rethrow;
    }
  }

  Future<Map<String, String>> _headers({bool authenticated = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (authenticated) {
      final token = await tokenStorage.readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  dynamic _decodeBody(http.Response response) {
    if (response.body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  T _requireSuccess<T>(
    http.Response response,
    T Function(dynamic body) onSuccess,
  ) {
    final body = _decodeBody(response);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return onSuccess(body);
    }
    throw AuthException(
      _extractErrorMessage(response),
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _asMap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body;
    }
    if (body is Map) {
      return body.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _asList(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map>()
          .map((item) => item.cast<String, dynamic>())
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  dynamic _extractData(dynamic body) {
    if (body is Map && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  Future<Map<String, dynamic>> _sendMultipart({
    required String path,
    required String fieldName,
    required Uint8List bytes,
    required String fileName,
    Map<String, String>? fields,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path));
    final token = await tokenStorage.readToken();
    request.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(
      http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
    );
    if (fields != null) {
      request.fields.addAll(fields);
    }
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<void> signup(Map<String, dynamic> payload) async {
    final response = await _httpPost(
      _uri('/api/auth/signup'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    _requireSuccess<void>(response, (_) {});
  }

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _httpPost(
      _uri('/api/auth/login'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _requireSuccess<String>(response, (body) {
      final data = _asMap(_extractData(body));
      final token =
          data['token']?.toString() ??
          data['jwt']?.toString() ??
          data['accessToken']?.toString() ??
          '';
      final refreshToken =
          data['refreshToken']?.toString() ??
          data['refresh']?.toString() ??
          '';
      if (token.isEmpty) {
        throw const AuthException('Réponse de connexion invalide');
      }
      if (refreshToken.isNotEmpty) {
        unawaited(tokenStorage.saveRefreshToken(refreshToken));
      }
      return token;
    });
  }

  @override
  Future<void> refreshSession() async {
    final refreshed = await _tryRefreshTokens();
    if (!refreshed) {
      throw const AuthException('Session expirée, reconnecte-toi', statusCode: 401);
    }
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    final token = await tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      final headers = await _headers(authenticated: true);
      await _safeNet(
        () => http.post(
          _uri('/api/auth/logout'),
          headers: headers,
          body: jsonEncode({
            if (refreshToken != null && refreshToken.trim().isNotEmpty)
              'refreshToken': refreshToken.trim(),
          }),
        ),
      );
    }
    await tokenStorage.clearToken();
  }

  @override
  Future<Map<String, dynamic>> getMe() async {
    final response = await _httpGet(
      _uri('/api/users/me'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    final response = await _httpPut(
      _uri('/api/users/me'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> updatePack(String packId) async {
    final response = await _httpPatch(
      _uri('/api/users/me/pack'),
      headers: await _headers(authenticated: true),
      body: jsonEncode({'packId': packId}),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<List<Map<String, dynamic>>> getPacks() async {
    final response = await _httpGet(
      _uri('/api/packs'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asList(_extractData(body)));
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages() async {
    final response = await _httpGet(
      _uri('/api/messages'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) {
      final data = _extractData(body);
      if (data is Map && data['items'] is List) {
        return _asList(data['items']);
      }
      return _asList(data);
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getOffers() async {
    final response = await _httpGet(
      _uri('/api/offers'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asList(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  }) {
    return _sendMultipart(
      path: '/api/users/me/media/photos',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
    );
  }

  @override
  Future<Map<String, dynamic>> uploadJustificatifPdf({
    required Uint8List bytes,
    required String fileName,
    String? category,
  }) {
    return _sendMultipart(
      path: '/api/users/me/media/justificatifs',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
      fields: category == null || category.trim().isEmpty
          ? null
          : <String, String>{'category': category.trim()},
    );
  }

  @override
  Future<List<Map<String, dynamic>>> listMyMedia({String? category}) async {
    final response = await _httpGet(
      _uri('/api/users/me/media',
          category == null ? null : {'category': category}),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asList(_extractData(body)));
  }

  @override
  Future<void> deleteMyMedia(String mediaId) async {
    final response = await _httpDelete(
      _uri('/api/users/me/media/$mediaId'),
      headers: await _headers(authenticated: true),
    );
    _requireSuccess<void>(response, (_) {});
  }

  // ============================================================
  // Matching
  // ============================================================

  @override
  Future<Map<String, dynamic>> fetchRecommendations({bool includeSwiped = false}) async {
    final query = includeSwiped ? <String, String>{'includeSwiped': 'true'} : null;
    final response = await _httpGet(
      _uri('/api/match/recommendations', query),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> recordSwipe({
    required String offerId,
    required String action,
  }) async {
    final response = await _httpPost(
      _uri('/api/match/swipe'),
      headers: await _headers(authenticated: true),
      body: jsonEncode({'offerId': offerId, 'action': action}),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> fetchSchoolRecommendations({String? secteur}) async {
    final query = <String, String>{};
    if (secteur != null && secteur.trim().isNotEmpty) {
      query['secteur'] = secteur.trim();
    }
    final response = await _httpGet(
      _uri('/api/match/school-recommendations', query.isEmpty ? null : query),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> fetchProfileRecommendations({
    bool includeSwiped = false,
  }) async {
    final query = includeSwiped ? <String, String>{'includeSwiped': 'true'} : null;
    final response = await _httpGet(
      _uri('/api/match/profile-recommendations', query),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> recordProfileSwipe({
    required String targetUserId,
    required String action,
  }) async {
    final response = await _httpPost(
      _uri('/api/match/profile-swipe'),
      headers: await _headers(authenticated: true),
      body: jsonEncode({'targetUserId': targetUserId, 'action': action}),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMutualMatches() async {
    final response = await _httpGet(
      _uri('/api/match/mutual'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) {
      final data = _asMap(_extractData(body));
      if (data['mutualMatches'] is List) {
        return _asList(data['mutualMatches']);
      }
      return _asList(data);
    });
  }

  @override
  Future<Map<String, dynamic>> fetchMyStats() async {
    final response = await _httpGet(
      _uri('/api/users/me/stats'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String sessionId,
    String? context,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'sessionId': sessionId,
      if (context != null && context.trim().isNotEmpty) 'context': context.trim(),
    };
    final response = await _httpPost(
      _uri('/api/chat'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(body),
    );
    return _requireSuccess(response, (b) => _asMap(_extractData(b)));
  }

  // ============================================================
  // Messagerie
  // ============================================================

  @override
  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String content,
    String? relatedOfferId,
  }) async {
    final body = <String, dynamic>{
      'receiverId': receiverId,
      'content': content,
    };
    if (relatedOfferId != null && relatedOfferId.isNotEmpty) {
      body['relatedOfferId'] = relatedOfferId;
    }
    final response = await _httpPost(
      _uri('/api/messages'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(body),
    );
    return _requireSuccess(response, (b) => _asMap(_extractData(b)));
  }

  @override
  Future<List<Map<String, dynamic>>> getConversation(String userId) async {
    final response = await _httpGet(
      _uri('/api/messages/conversation/$userId'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asList(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> markMessageRead(String messageId) async {
    final response = await _httpPut(
      _uri('/api/messages/$messageId/read'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<void> deleteMessage(String messageId) async {
    final response = await _httpDelete(
      _uri('/api/messages/$messageId'),
      headers: await _headers(authenticated: true),
    );
    _requireSuccess<void>(response, (_) {});
  }

  // ============================================================
  // Offres CRUD
  // ============================================================

  @override
  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> payload) async {
    final response = await _httpPost(
      _uri('/api/offers'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> updateOffer(
    String offerId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _httpPut(
      _uri('/api/offers/$offerId'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<void> deleteOffer(String offerId) async {
    final response = await _httpDelete(
      _uri('/api/offers/$offerId'),
      headers: await _headers(authenticated: true),
    );
    _requireSuccess<void>(response, (_) {});
  }

  @override
  Future<Map<String, dynamic>> uploadOfferPdf({
    required String offerId,
    required Uint8List bytes,
    required String fileName,
  }) {
    return _sendMultipart(
      path: '/api/offers/$offerId/media',
      fieldName: 'file',
      bytes: bytes,
      fileName: fileName,
    );
  }

  @override
  Future<Map<String, dynamic>> getOfferLikedBy(String offerId) async {
    final response = await _httpGet(
      _uri('/api/offers/$offerId/liked-by'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  // ============================================================
  // Schools
  // ============================================================

  @override
  Future<List<Map<String, dynamic>>> listSchools() async {
    final response = await _httpGet(
      _uri('/api/schools'),
      headers: await _headers(),
    );
    return _requireSuccess(response, (body) => _asList(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> createSchool(Map<String, dynamic> payload) async {
    final response = await _httpPost(
      _uri('/api/schools'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> updateSchool(
    String schoolId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _httpPut(
      _uri('/api/schools/$schoolId'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  // ============================================================
  // Companies
  // ============================================================

  @override
  Future<List<Map<String, dynamic>>> listCompanies() async {
    final response = await _httpGet(
      _uri('/api/companies'),
      headers: await _headers(),
    );
    return _requireSuccess(response, (body) => _asList(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> payload) async {
    final response = await _httpPost(
      _uri('/api/companies'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  @override
  Future<Map<String, dynamic>> updateCompany(
    String companyId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _httpPut(
      _uri('/api/companies/$companyId'),
      headers: await _headers(authenticated: true),
      body: jsonEncode(payload),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  // ============================================================
  // Feature access
  // ============================================================

  @override
  Future<Map<String, dynamic>> getFeatureAccess() async {
    final response = await _httpGet(
      _uri('/api/features/access-summary'),
      headers: await _headers(authenticated: true),
    );
    return _requireSuccess(response, (body) => _asMap(_extractData(body)));
  }

  String _extractErrorMessage(http.Response response) {
    final statusCode = response.statusCode;
    final body = _decodeBody(response);

    final bodyMessage = _extractMessageFromBody(body, statusCode: statusCode);
    if (bodyMessage != null && bodyMessage.trim().isNotEmpty) {
      return bodyMessage;
    }

    final rawBody = response.body.trim();
    if (rawBody.isNotEmpty) {
      return _mapErrorMessage(rawBody, statusCode: statusCode);
    }

    return _defaultMessageForStatus(statusCode);
  }

  String? _extractMessageFromBody(dynamic body, {int? statusCode}) {
    if (body is! Map) return null;

    final map = body.cast<dynamic, dynamic>();
    final nestedError = map['error'];
    if (nestedError is Map) {
      final nestedMessage =
          nestedError['message']?.toString() ?? nestedError['detail']?.toString();
      if (nestedMessage != null && nestedMessage.trim().isNotEmpty) {
        return _mapErrorMessage(nestedMessage, statusCode: statusCode);
      }
    }

    final directMessage =
        map['message']?.toString() ??
        map['error']?.toString() ??
        map['detail']?.toString();
    if (directMessage != null && directMessage.trim().isNotEmpty) {
      return _mapErrorMessage(directMessage, statusCode: statusCode);
    }

    final validationMessage = _extractValidationMessage(map);
    if (validationMessage != null && validationMessage.trim().isNotEmpty) {
      return _mapErrorMessage(validationMessage, statusCode: statusCode);
    }

    return null;
  }

  String? _extractValidationMessage(Map<dynamic, dynamic> body) {
    final errors = body['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final key = entry.key?.toString() ?? 'champ';
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          final first = value.first?.toString().trim();
          if (first != null && first.isNotEmpty) return '$key: $first';
        }
        final text = value?.toString().trim();
        if (text != null && text.isNotEmpty) return '$key: $text';
      }
    }

    final fieldErrors = body['fieldErrors'];
    if (fieldErrors is List) {
      for (final item in fieldErrors) {
        if (item is Map) {
          final field =
              item['field']?.toString() ?? item['name']?.toString() ?? 'champ';
          final message =
              item['message']?.toString() ?? item['defaultMessage']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            return '$field: ${message.trim()}';
          }
        }
      }
    }

    final violations = body['violations'];
    if (violations is List) {
      for (final item in violations) {
        if (item is Map) {
          final field =
              item['field']?.toString() ?? item['propertyPath']?.toString() ?? 'champ';
          final message = item['message']?.toString();
          if (message != null && message.trim().isNotEmpty) {
            return '$field: ${message.trim()}';
          }
        }
      }
    }

    return null;
  }

  String _defaultMessageForStatus(int? statusCode) {
    if (statusCode == null) return 'Une erreur reseau est survenue';
    if (statusCode == 400) return 'Requete invalide';
    if (statusCode == 401) return 'Session expiree, reconnecte-toi';
    if (statusCode == 403) return 'Action non autorisee';
    if (statusCode == 404) return 'Ressource introuvable';
    if (statusCode == 409) return 'Conflit de donnees';
    if (statusCode == 413) return 'Fichier trop volumineux';
    if (statusCode == 415) return 'Format de fichier non supporte';
    if (statusCode == 422) return 'Donnees invalides';
    if (statusCode >= 500) return 'Erreur serveur, reessaie plus tard';
    return 'Une erreur reseau est survenue';
  }

  String _mapErrorMessage(String rawMessage, {int? statusCode}) {
    final message = rawMessage.trim();
    if (message.isEmpty) {
      return _defaultMessageForStatus(statusCode);
    }

    final lower = message.toLowerCase();

    if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
      return _defaultMessageForStatus(statusCode);
    }

    if (lower.contains('access denied') ||
        lower.contains('forbidden') ||
        lower.contains('not authorized') ||
        lower.contains('non autorise')) {
      return 'Action non autorisee';
    }
    if (lower.contains('validation failed') ||
        lower.contains('constraint') ||
        lower.contains('unprocessable entity')) {
      return 'Donnees invalides';
    }

    if (lower.contains('email deja utilise')) {
      return 'Cet email est déjà utilisé';
    }
    if (lower.contains('incorrect')) {
      return 'Identifiants invalides';
    }
    if (lower.contains('champ profil obligatoire')) {
      return 'Merci de remplir tous les champs obligatoires';
    }
    if (lower.contains('non authentifie') || lower.contains('jwt')) {
      return 'Session expirée, reconnecte-toi';
    }
    if (lower.contains('aucun fichier recu')) {
      return 'Aucun fichier reçu';
    }
    if (lower.contains('format image non supporte')) {
      return 'Format image non supporté (jpeg, png, webp, gif)';
    }
    if (lower.contains('image depasse') || lower.contains('8mb')) {
      return 'L\'image dépasse la taille maximale autorisée (8MB)';
    }
    if (lower.contains('pdf') && lower.contains('autorises')) {
      return 'Seuls les fichiers PDF sont autorisés pour les justificatifs';
    }
    if (lower.contains('pdf depasse') || lower.contains('12mb')) {
      return 'Le PDF dépasse la taille maximale autorisée (12MB)';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'Erreur serveur, reessaie plus tard';
    }

    return message;
  }
}

abstract class TokenStorage {
  Future<void> saveToken(String token);

  Future<String?> readToken();

  Future<void> saveRefreshToken(String token);

  Future<String?> readRefreshToken();

  Future<void> clearToken();
}

class SecureTokenStorage implements TokenStorage {
  const SecureTokenStorage();

  static const _key = 'auth_token';
  static const _refreshKey = 'refresh_token';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<void> saveToken(String token) {
    return _storage.write(key: _key, value: token);
  }

  @override
  Future<String?> readToken() {
    return _storage.read(key: _key);
  }

  @override
  Future<void> saveRefreshToken(String token) {
    return _storage.write(key: _refreshKey, value: token);
  }

  @override
  Future<String?> readRefreshToken() {
    return _storage.read(key: _refreshKey);
  }

  @override
  Future<void> clearToken() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _refreshKey);
  }
}

class MemoryTokenStorage implements TokenStorage {
  String? _token;
  String? _refreshToken;

  @override
  Future<void> clearToken() async {
    _token = null;
    _refreshToken = null;
  }

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> saveRefreshToken(String token) async {
    _refreshToken = token;
  }

  @override
  Future<String?> readRefreshToken() async => _refreshToken;

  @override
  Future<void> saveToken(String token) async {
    _token = token;
  }
}
