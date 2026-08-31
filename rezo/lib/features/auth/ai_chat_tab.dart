part of 'auth_flow.dart';

/// Onglet Chat IA connecté au backend.
/// UI complète: check d'accès, historique local, écran upgrade,
/// composer + bulles.
class _AiChatTab extends StatefulWidget {
  const _AiChatTab({super.key});

  @override
  State<_AiChatTab> createState() => _AiChatTabState();
}

class _AiChatTabState extends State<_AiChatTab> {
  bool _checking = true;
  bool _allowed = true;
  String? _deniedReason;
  String? _requiredPack;
  bool _bootstrapped = false;

  final List<_AiMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _waiting = false;
  String? _currentSessionId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_bootstrapped) {
      _bootstrapped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _bootstrap();
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final appState = AppScope.of(context);
      final access = await appState.getFeatureAccess();
      final entry = access['chat-ai'] ?? access['chatAi'] ?? access['ai'];
      bool allowed = true;
      String? reason;
      String? pack;
      if (entry is Map) {
        if (entry['allowed'] is bool) allowed = entry['allowed'] as bool;
        reason = entry['reason']?.toString();
        pack = entry['requiredPack']?.toString() ??
            entry['packRequis']?.toString();
      }
      if (!mounted) return;
      setState(() {
        _allowed = allowed;
        _deniedReason = reason;
        _requiredPack = pack;
        _checking = false;
      });
      if (allowed) {
        _currentSessionId ??= _buildSessionId();
        await _loadHistory();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _allowed = true;
        _checking = false;
      });
      _currentSessionId ??= _buildSessionId();
      await _loadHistory();
    }
  }

  String _buildSessionId() {
    return _generateUuidV4();
  }

  bool _isValidUuid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    final trimmed = value.trim();
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}',
    );
    final match = regex.matchAsPrefix(trimmed);
    return match != null && match.end == trimmed.length;
  }

  String _generateUuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // UUIDv4: version=4, variant=10xx
    bytes[6] = (bytes[6] & 0x0F) | 0x40;
    bytes[8] = (bytes[8] & 0x3F) | 0x80;

    String hexByte(int b) => b.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(hexByte).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  String _historyKey() {
    final user = AppScope.of(context).currentUser ?? const <String, dynamic>{};
    final id = user['id']?.toString() ?? 'anonymous';
    return 'ai_chat_history_$id';
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey());
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final list = decoded
          .whereType<Map>()
          .map((e) => _AiMessage.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });
      _scrollToBottom();
    } catch (_) {
      // historique corrompu : on ignore
    }
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString(_historyKey(), encoded);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _clearHistory() async {
    setState(() => _messages.clear());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey());
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _waiting) return;
    final sessionId = _isValidUuid(_currentSessionId)
        ? _currentSessionId!
        : _buildSessionId();
    _currentSessionId = sessionId;
    final userMsg = _AiMessage(
      role: 'user',
      content: text,
      timestamp: DateTime.now(),
    );
    setState(() {
      _messages.add(userMsg);
      _inputController.clear();
      _waiting = true;
    });
    unawaited(_saveHistory());
    _scrollToBottom();

    try {
      final appState = AppScope.of(context);
      final response = await appState.sendChatMessage(
        message: text,
        sessionId: sessionId,
      );
      if (!mounted) return;
      final iaResponse = response['iaResponse']?.toString() ??
          response['assistantMessage']?.toString() ??
          response['response']?.toString() ??
          '';
      final returnedSessionId = response['sessionId']?.toString();
      if (returnedSessionId != null && returnedSessionId.isNotEmpty) {
        _currentSessionId = returnedSessionId;
      }
      final aiMsg = _AiMessage(
        role: 'assistant',
        content: iaResponse.isEmpty
            ? 'Je n\'ai pas pu generer de reponse pour le moment.'
            : iaResponse,
        timestamp: DateTime.now(),
      );
      setState(() {
        _messages.add(aiMsg);
        _waiting = false;
      });
      unawaited(_saveHistory());
      _scrollToBottom();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _waiting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _waiting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le chat IA est temporairement indisponible.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_allowed) {
      return _buildDenied();
    }
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? _buildEmpty()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length + (_waiting ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i == _messages.length && _waiting) {
                      return const _TypingIndicator();
                    }
                    return _ChatBubble(message: _messages[i]);
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE0E0E0))),
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Effacer la conversation',
                  onPressed: _messages.isEmpty ? null : _confirmClear,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Pose ta question…',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _waiting ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                  child: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Effacer la conversation ?'),
        content: const Text('L\'historique local sera supprimé.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (ok == true) await _clearHistory();
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.smart_toy_outlined, size: 56),
            SizedBox(height: 16),
            Text(
              'Démarre la conversation',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 8),
            Text(
              "Pose une question à ton assistant REZO pour t'aider dans ton orientation, ta recherche d'opportunités ou tes choix professionnels.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Chat IA non disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _deniedReason ??
                  "Votre pack actuel ne permet pas d'utiliser l'assistant IA.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            if (_requiredPack != null) ...[
              const SizedBox(height: 8),
              Text(
                'Pack requis : $_requiredPack',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                final shell =
                    context.findAncestorStateOfType<_DashboardScreenState>();
                shell?.goToProfile();
              },
              icon: const Icon(Icons.workspace_premium_rounded),
              label: const Text('Voir les packs'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiMessage {
  _AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
  });

  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory _AiMessage.fromJson(Map<String, dynamic> j) => _AiMessage(
        role: j['role']?.toString() ?? 'assistant',
        content: j['content']?.toString() ?? '',
        timestamp: DateTime.tryParse(j['timestamp']?.toString() ?? '') ??
            DateTime.now(),
      );
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});
  final _AiMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    final bg = isUser ? Colors.black : const Color(0xFFF1F1F1);
    final fg = isUser ? Colors.white : Colors.black87;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 2),
            bottomRight: Radius.circular(isUser ? 2 : 14),
          ),
        ),
        child: Text(message.content, style: TextStyle(color: fg)),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_controller.value * 3 - i).clamp(0.0, 1.0);
                final opacity =
                    (t < 0.5 ? t * 2 : (1 - t) * 2).clamp(0.2, 1.0);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Opacity(
                    opacity: opacity,
                    child: const CircleAvatar(
                      radius: 4,
                      backgroundColor: Colors.black54,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}
