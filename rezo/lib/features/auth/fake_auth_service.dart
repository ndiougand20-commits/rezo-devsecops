part of 'auth_flow.dart';

class FakeAuthService implements AuthService {
  FakeAuthService({
    this.shouldFailLogin = false,
    this.shouldFailSignup = false,
    this.shouldFailGetMe = false,
    Map<String, dynamic>? seededUser,
  }) : _user = Map<String, dynamic>.from(seededUser ?? _defaultUser);

  final bool shouldFailLogin;
  final bool shouldFailSignup;
  final bool shouldFailGetMe;
  final Map<String, dynamic> _user;
  final List<Map<String, dynamic>> _media = <Map<String, dynamic>>[];

  static const _defaultUser = <String, dynamic>{
    'id': 'user-1',
    'email': 'awa@rezo.sn',
    'prenom': 'Awa',
    'nom': 'Fall',
    'telephone': '+221770000001',
    'role': 'ETUDIANT',
    'packNom': 'FREE',
    'packFeatures': ['MATCHING_BASIC', 'MESSAGERIE_LIMITEE'],
    'canManageOffers': false,
    'profil': {
      'niveauEtude': 'Licence 3',
      'domaine': 'Informatique',
      'competences': ['Flutter', 'Java'],
      'objectif': 'Trouver un stage',
      'preferencesSecteur': ['IT'],
      'preferencesLieu': ['Dakar'],
    },
  };

  @override
  Future<Map<String, dynamic>> getMe() async {
    if (shouldFailGetMe) {
      throw AuthException('Session expirée, reconnecte-toi', statusCode: 401);
    }

    return _cloneMap(_user);
  }

  @override
  Future<String> login({
    required String email,
    required String password,
  }) async {
    if (shouldFailLogin) {
      throw AuthException('Identifiants invalides', statusCode: 401);
    }
    return 'fake-jwt-token';
  }

  @override
  Future<void> refreshSession() async {}

  @override
  Future<void> logout({String? refreshToken}) async {}

  @override
  Future<void> signup(Map<String, dynamic> payload) async {
    if (shouldFailSignup) {
      throw AuthException('Cet email est déjà utilisé', statusCode: 409);
    }
  }

  @override
  Future<Map<String, dynamic>> updateMe(Map<String, dynamic> payload) async {
    _user.addAll(payload);
    final incomingProfile = payload['profil'];
    if (incomingProfile is Map) {
      final existing =
          (_user['profil'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      _user['profil'] = {
        ...existing,
        ...incomingProfile.cast<String, dynamic>(),
      };
    }
    return _cloneMap(_user);
  }

  @override
  Future<Map<String, dynamic>> updatePack(String packId) async {
    final selected = (await getPacks()).firstWhere(
      (pack) => (pack['id']?.toString() ?? '') == packId,
      orElse: () => {'id': packId, 'nom': 'CUSTOM', 'features': <String>[]},
    );
    _user['packId'] = selected['id'];
    _user['packNom'] = selected['nom'];
    _user['packFeatures'] = selected['features'] ?? const <String>[];
    return _cloneMap(_user);
  }

  @override
  Future<Map<String, dynamic>> uploadProfilePhoto({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final media = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'category': 'PHOTO',
      'originalFileName': fileName,
      'contentType': 'image/*',
      'fileUrl': '/uploads/users/${_user['id']}/photos/$fileName',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _media.removeWhere((entry) => entry['category']?.toString() == 'PHOTO');
    _media.add(media);
    _user['avatarUrl'] = media['fileUrl'];
    return _cloneMap(media);
  }

  @override
  Future<Map<String, dynamic>> uploadJustificatifPdf({
    required Uint8List bytes,
    required String fileName,
    String? category,
  }) async {
    final normalizedCategory =
        (category == null || category.trim().isEmpty)
        ? 'JUSTIFICATIF_PDF'
        : category.trim().toUpperCase();
    final media = {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'category': normalizedCategory,
      'originalFileName': fileName,
      'contentType': 'application/pdf',
      'fileUrl': '/uploads/users/${_user['id']}/justificatifs/$fileName',
      'createdAt': DateTime.now().toIso8601String(),
    };
    _media.add(media);
    return _cloneMap(media);
  }

  @override
  Future<List<Map<String, dynamic>>> listMyMedia({String? category}) async {
    final normalizedCategory = category?.trim().toUpperCase();
    return _media
        .where(
          (entry) =>
              normalizedCategory == null ||
              entry['category']?.toString().toUpperCase() == normalizedCategory,
        )
        .map(_cloneMap)
        .toList();
  }

  @override
  Future<void> deleteMyMedia(String mediaId) async {
    final before = _media.length;
    _media.removeWhere((entry) => entry['id']?.toString() == mediaId);
    if (before == _media.length) {
      throw AuthException('Media introuvable', statusCode: 404);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getPacks() async {
    return const [
      {
        'id': 'pack-free',
        'nom': 'FREE',
        'description': 'Accès de base',
        'features': ['MATCHING_BASIC'],
      },
      {
        'id': 'pack-pro',
        'nom': 'PRO',
        'description': 'Accès avancé + messagerie illimitée',
        'features': ['MATCHING_ADVANCED', 'MESSAGERIE_ILLIMITEE'],
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getMessages() async {
    return const [
      {'content': 'Bienvenue sur REZO', 'createdAt': '2026-04-13T10:30:00'},
      {
        'content': 'Ton profil attire déjà des opportunités',
        'createdAt': '2026-04-12T09:15:00',
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> getOffers() async {
    return [
      {
        'ownerUserId': _user['id']?.toString() ?? 'user-1',
        'titre': 'Stage Flutter',
        'datePublication': '2026-04-10T08:00:00',
      },
    ];
  }

  // ---- Matching ----
  @override
  Future<Map<String, dynamic>> fetchRecommendations({bool includeSwiped = false}) async {
    return <String, dynamic>{
      'recommendations': <Map<String, dynamic>>[],
      'suggestedPack': null,
      'trace': <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> recordSwipe({
    required String offerId,
    required String action,
  }) async {
    return <String, dynamic>{
      'swipeId': '00000000-0000-0000-0000-000000000000',
      'offerId': offerId,
      'action': action,
    };
  }

  @override
  Future<Map<String, dynamic>> fetchSchoolRecommendations({String? secteur}) async {
    return <String, dynamic>{
      'secteur': secteur,
      'recommendations': <Map<String, dynamic>>[],
      'trace': <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> fetchProfileRecommendations({
    bool includeSwiped = false,
  }) async {
    return <String, dynamic>{
      'includeSwiped': includeSwiped,
      'recommendations': <Map<String, dynamic>>[],
      'trace': <String, dynamic>{},
    };
  }

  @override
  Future<Map<String, dynamic>> recordProfileSwipe({
    required String targetUserId,
    required String action,
  }) async {
    return <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'targetUserId': targetUserId,
      'action': action,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMutualMatches() async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> fetchMyStats() async {
    return <String, dynamic>{
      'matchCount': 0,
      'likesSent': 0,
      'likesReceived': 0,
      'offerCount': 0,
      'unreadMessages': 0,
    };
  }

  @override
  Future<Map<String, dynamic>> sendChatMessage({
    required String message,
    required String sessionId,
    String? context,
  }) async {
    return <String, dynamic>{
      'userMessage': message,
      'iaResponse': 'Assistant indisponible en mode fake.',
      'sessionId': sessionId,
      'context': context,
    };
  }

  // ---- Messagerie ----
  @override
  Future<Map<String, dynamic>> sendMessage({
    required String receiverId,
    required String content,
    String? relatedOfferId,
  }) async {
    return <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'receiverId': receiverId,
      'content': content,
      'relatedOfferId': relatedOfferId,
      'isRead': false,
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getConversation(String userId) async {
    return <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> markMessageRead(String messageId) async {
    return <String, dynamic>{'id': messageId, 'isRead': true};
  }

  @override
  Future<void> deleteMessage(String messageId) async {}

  // ---- Offres CRUD ----
  @override
  Future<Map<String, dynamic>> createOffer(Map<String, dynamic> payload) async {
    return <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      ...payload,
    };
  }

  @override
  Future<Map<String, dynamic>> updateOffer(
    String offerId,
    Map<String, dynamic> payload,
  ) async {
    return <String, dynamic>{'id': offerId, ...payload};
  }

  @override
  Future<void> deleteOffer(String offerId) async {}

  @override
  Future<Map<String, dynamic>> uploadOfferPdf({
    required String offerId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    return <String, dynamic>{
      'offerId': offerId,
      'pdfUrl': '/uploads/offers/$offerId/$fileName',
      'fileName': fileName,
    };
  }

  @override
  Future<Map<String, dynamic>> getOfferLikedBy(String offerId) async {
    return <String, dynamic>{
      'offerId': offerId,
      'count': 0,
      'likers': <Map<String, dynamic>>[],
    };
  }

  // ---- Schools ----
  @override
  Future<List<Map<String, dynamic>>> listSchools() async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> createSchool(Map<String, dynamic> payload) async {
    return <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'ownerUserId': _user['id'],
      ...payload,
    };
  }

  @override
  Future<Map<String, dynamic>> updateSchool(
    String schoolId,
    Map<String, dynamic> payload,
  ) async {
    return <String, dynamic>{'id': schoolId, ...payload};
  }

  // ---- Companies ----
  @override
  Future<List<Map<String, dynamic>>> listCompanies() async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> createCompany(Map<String, dynamic> payload) async {
    return <String, dynamic>{
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'ownerUserId': _user['id'],
      ...payload,
    };
  }

  @override
  Future<Map<String, dynamic>> updateCompany(
    String companyId,
    Map<String, dynamic> payload,
  ) async {
    return <String, dynamic>{'id': companyId, ...payload};
  }

  // ---- Feature access ----
  @override
  Future<Map<String, dynamic>> getFeatureAccess() async {
    return <String, dynamic>{
      'packNom': _user['packNom'],
      'canViewOpportunities': true,
      'canManageOffers': _user['canManageOffers'] ?? false,
      'canUseMessaging': true,
      'canUseAiChat': false,
    };
  }

  Map<String, dynamic> _cloneMap(Map<String, dynamic> source) {
    return jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  }
}
