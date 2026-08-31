part of 'auth_flow.dart';

class _MessagesTab extends StatefulWidget {
  const _MessagesTab({super.key});

  @override
  State<_MessagesTab> createState() => _MessagesTabState();
}

class _MessagesTabState extends State<_MessagesTab> {
  static const int _conversationPageSize = 12;

  List<_Conversation>? _conversations;
  Set<String> _matchedUserIds = <String>{};
  Map<String, _MatchedMeta> _matchedMetaByUserId = <String, _MatchedMeta>{};
  bool _isLoading = true;
  String? _error;
  _Conversation? _selected;
  bool? _messagingAllowed;
  String? _messagingDeniedReason;
  int _conversationPage = 0;
  Timer? _pollingTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_conversations == null && _isLoading) {
      _bootstrap();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _checkAccess();
    if (!mounted) return;
    if (_messagingAllowed == false) {
      setState(() => _isLoading = false);
      return;
    }
    await _loadMutualMatches();
    if (!mounted) return;
    await _loadConversations();
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (!mounted) return;
      if (_isLoading || _selected != null) return;
      unawaited(_loadConversations());
    });
  }

  Future<void> _loadMutualMatches() async {
    try {
      final appState = AppScope.of(context);
      final mutual = await appState.fetchMutualMatches();
      final ids = <String>{};
      final metaById = <String, _MatchedMeta>{};
      for (final entry in mutual) {
        final id = entry['matchedUserId']?.toString() ??
            entry['otherUserId']?.toString() ??
            entry['userId']?.toString() ??
            '';
        if (id.isNotEmpty) {
          ids.add(id);
          final name = _firstNonEmpty([
            entry['matchedUserName']?.toString(),
            entry['otherUserName']?.toString(),
            entry['userName']?.toString(),
          ], fallback: 'Contact');
          final matchedAt = entry['matchedAt']?.toString() ?? '';
          metaById[id] = _MatchedMeta(name: name, matchedAt: matchedAt);
        }
      }
      if (!mounted) return;
      setState(() {
        _matchedUserIds = ids;
        _matchedMetaByUserId = metaById;
      });
    } catch (_) {
      // En cas d'erreur API, on garde une liste vide (aucune conversation visible).
      if (!mounted) return;
      setState(() {
        _matchedUserIds = <String>{};
        _matchedMetaByUserId = <String, _MatchedMeta>{};
      });
    }
  }

  Future<void> _checkAccess() async {
    try {
      final appState = AppScope.of(context);
      final access = await appState.getFeatureAccess();
      final messaging = (access['messaging'] as Map?)?.cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _messagingAllowed = messaging?['allowed'] != false;
        _messagingDeniedReason = messaging?['reason']?.toString();
      });
    } catch (_) {
      // Si l'API d'accès échoue, on considère que la messagerie est ouverte
      // (le backend enforcera de toutes façons les permissions).
      if (!mounted) return;
      setState(() => _messagingAllowed = true);
    }
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final appState = AppScope.of(context);
      final myId = appState.currentUser?['id']?.toString() ?? '';
      final rawMessages = await appState.fetchMessages();
      final grouped = _groupByInterlocutor(rawMessages, myId)
          .where((conv) => _matchedUserIds.contains(conv.otherUserId))
          .toList();
      final existingIds = grouped.map((c) => c.otherUserId).toSet();
      for (final matchedId in _matchedUserIds) {
        if (existingIds.contains(matchedId)) continue;
        final meta = _matchedMetaByUserId[matchedId];
        grouped.add(
          _Conversation(
            otherUserId: matchedId,
            otherName: meta?.name ?? 'Contact',
            lastMessage: 'Nouveau match. Envoie ton premier message.',
            lastDate: meta?.matchedAt ?? DateTime.now().toIso8601String(),
            unreadCount: 0,
            lastIsFromMe: false,
            isMatch: true,
            isSynthetic: true,
          ),
        );
      }
      grouped.sort((a, b) {
        final da = DateTime.tryParse(a.lastDate) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b.lastDate) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      if (!mounted) return;
      setState(() {
        _conversations = grouped;
        _conversationPage = 0;
        _isLoading = false;
      });
    } on AuthException catch (e) {
      if (e.statusCode == 401 && mounted) {
        final appState = AppScope.of(context);
        await appState.logout();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.welcome,
          (route) => false,
        );
        return;
      }
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger les messages';
        _isLoading = false;
      });
    }
  }

  List<_Conversation> _groupByInterlocutor(
    List<Map<String, dynamic>> messages,
    String myId,
  ) {
    final byOther = <String, List<Map<String, dynamic>>>{};
    final namesByOther = <String, String>{};
    for (final m in messages) {
      final senderId = m['senderId']?.toString() ?? '';
      final receiverId = m['receiverId']?.toString() ?? '';
      final isFromMe = senderId == myId;
      final otherId = isFromMe ? receiverId : senderId;
      if (otherId.isEmpty) continue;
      final rawOtherName = isFromMe
          ? m['receiverName']?.toString()
          : m['senderName']?.toString();
      final otherName = _firstNonEmpty([
        rawOtherName,
        _matchedMetaByUserId[otherId]?.name,
      ], fallback: 'Contact');
      byOther.putIfAbsent(otherId, () => <Map<String, dynamic>>[]).add(m);
      namesByOther.putIfAbsent(otherId, () => otherName);
    }
    final convs = <_Conversation>[];
    for (final entry in byOther.entries) {
      final list = [...entry.value]..sort((a, b) {
          final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });
      final last = list.first;
      final unread = list.where((m) {
        final senderId = m['senderId']?.toString() ?? '';
        final isFromMe = senderId == myId;
        return !isFromMe && m['read'] != true && m['isRead'] != true;
      }).length;
      convs.add(_Conversation(
        otherUserId: entry.key,
        otherName: _firstNonEmpty([
          namesByOther[entry.key],
          _matchedMetaByUserId[entry.key]?.name,
        ], fallback: 'Contact'),
        lastMessage: last['content']?.toString() ?? '',
        lastDate: last['createdAt']?.toString() ?? '',
        unreadCount: unread,
        lastIsFromMe: (last['senderId']?.toString() ?? '') == myId,
        isMatch: _matchedUserIds.contains(entry.key),
      ));
    }
    convs.sort((a, b) {
      final da = DateTime.tryParse(a.lastDate) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final db = DateTime.tryParse(b.lastDate) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return convs;
  }

  String _firstNonEmpty(List<String?> values, {required String fallback}) {
    for (final value in values) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_messagingAllowed == false) {
      return _buildMessagingDenied();
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48,
                  color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _loadConversations,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('R\u00e9essayer'),
              ),
            ],
          ),
        ),
      );
    }

    final conversations = _conversations ?? const <_Conversation>[];
    final visibleCount =
      ((_conversationPage + 1) * _conversationPageSize).clamp(0, conversations.length);
    final visibleConversations = conversations.take(visibleCount).toList();
    final hasMoreConversations = visibleCount < conversations.length;

    if (_selected != null) {
      return _ConversationDetailView(
        conversation: _selected!,
        onBack: () {
          setState(() => _selected = null);
          unawaited(_loadConversations());
        },
        onChanged: _loadConversations,
      );
    }

    if (conversations.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadConversations,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _FeaturePlaceholderCard(
              title: 'Messagerie REZO',
              subtitle:
                  'Tes conversations appara\u00eetront ici d\u00e8s le premier match.',
              icon: Icons.forum_rounded,
              accent: Color(0xFFE8F0FF),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: visibleConversations.length + (hasMoreConversations ? 1 : 0),
        separatorBuilder: (_, index) {
          if (index >= visibleConversations.length - 1) {
            return const SizedBox(height: 10);
          }
          return const Divider(height: 1);
        },
        itemBuilder: (context, index) {
          if (index == visibleConversations.length && hasMoreConversations) {
            final remaining = conversations.length - visibleConversations.length;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _conversationPage += 1),
                  icon: const Icon(Icons.expand_more_rounded),
                  label: Text('Voir plus ($remaining restantes)'),
                ),
              ),
            );
          }

          final conv = visibleConversations[index];
          final preview = conv.isSynthetic
            ? conv.lastMessage
            : conv.lastIsFromMe
              ? 'Vous : ${conv.lastMessage}'
              : conv.lastMessage;
          final truncated =
              preview.length > 60 ? '${preview.substring(0, 60)}\u2026' : preview;
          return _ConversationTile(
            senderName: conv.otherName,
            lastMessage: truncated,
            date: _formatMessageDate(conv.lastDate),
            unreadCount: conv.unreadCount,
            isMatch: conv.isMatch,
            onTap: () => setState(() => _selected = conv),
          );
        },
      ),
    );
  }

  Widget _buildMessagingDenied() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Messagerie non disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(
              _messagingDeniedReason ??
                  "Votre pack actuel ne permet pas d'utiliser la messagerie.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () {
                final shell = context
                    .findAncestorStateOfType<_DashboardScreenState>();
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

  String _formatMessageDate(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) return "\u00e0 l'instant";
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}j';
    return '${parsed.day}/${parsed.month}/${parsed.year}';
  }
}

class _Conversation {
  const _Conversation({
    required this.otherUserId,
    required this.otherName,
    required this.lastMessage,
    required this.lastDate,
    required this.unreadCount,
    required this.lastIsFromMe,
    required this.isMatch,
    this.isSynthetic = false,
  });

  final String otherUserId;
  final String otherName;
  final String lastMessage;
  final String lastDate;
  final int unreadCount;
  final bool lastIsFromMe;
  final bool isMatch;
  final bool isSynthetic;
}

class _MatchedMeta {
  const _MatchedMeta({required this.name, required this.matchedAt});

  final String name;
  final String matchedAt;
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.senderName,
    required this.lastMessage,
    required this.date,
    required this.unreadCount,
    required this.isMatch,
    required this.onTap,
  });

  final String senderName;
  final String lastMessage;
  final String date;
  final int unreadCount;
  final bool isMatch;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = unreadCount > 0;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFF0F0F0),
        child: Text(
          senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      title: Text(
        senderName,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: SizedBox(
        width: 88,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(date, style: const TextStyle(fontSize: 12)),
            if (isMatch || isUnread) const SizedBox(height: 4),
            if (isMatch || isUnread)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isMatch)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF81C784)),
                      ),
                      child: const Text(
                        'Match',
                        style: TextStyle(
                          color: Color(0xFF2E7D32),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (isMatch && isUnread) const SizedBox(width: 4),
                  if (isUnread)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      onTap: onTap,
    );
  }
}

class _ConversationDetailView extends StatefulWidget {
  const _ConversationDetailView({
    required this.conversation,
    required this.onBack,
    required this.onChanged,
  });

  final _Conversation conversation;
  final VoidCallback onBack;
  final VoidCallback onChanged;

  @override
  State<_ConversationDetailView> createState() =>
      _ConversationDetailViewState();
}

class _ConversationDetailViewState extends State<_ConversationDetailView> {
  static const int _historyPageSize = 30;

  List<Map<String, dynamic>> _messages = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  int _historyPage = 0;
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadMessages();
    });
  }

  @override
  void dispose() {
    _composer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final appState = AppScope.of(context);
      final myId = appState.currentUser?['id']?.toString() ?? '';
      final messages =
          await appState.getConversation(widget.conversation.otherUserId);
      messages.sort((a, b) {
        final da = DateTime.tryParse(a['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse(b['createdAt']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return da.compareTo(db);
      });
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _historyPage = 0;
        _isLoading = false;
      });
      _scrollToBottom();
      // Marquer comme lu en arrière-plan
      for (final m in messages) {
        final senderId = m['senderId']?.toString() ?? '';
        final isUnread = m['read'] != true && m['isRead'] != true;
        if (isUnread && senderId != myId) {
          final id = m['id']?.toString();
          if (id == null) continue;
          unawaited(appState
              .markMessageRead(id)
              .catchError((Object _) => <String, dynamic>{}));
        }
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la conversation';
        _isLoading = false;
      });
    }
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

  Future<void> _sendMessage() async {
    if (!widget.conversation.isMatch) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez avoir un match mutuel pour envoyer un message.'),
        ),
      );
      return;
    }

    final text = _composer.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    try {
      final appState = AppScope.of(context);
      await appState.sendMessage(
        receiverId: widget.conversation.otherUserId,
        content: text,
      );
      _composer.clear();
      await _loadMessages();
      widget.onChanged();
    } on AuthException catch (e) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (e.statusCode == 403) {
        final lower = e.message.toLowerCase();
        if (lower.contains('joignable') ||
            lower.contains('destinataire')) {
          messenger.showSnackBar(SnackBar(content: Text(e.message)));
        } else {
          messenger.showSnackBar(SnackBar(
            content: const Text(
                'Votre pack ne permet pas d\u2019envoyer des messages.'),
            action: SnackBarAction(
              label: 'Upgrade',
              onPressed: () {
                final shell = context
                    .findAncestorStateOfType<_DashboardScreenState>();
                shell?.goToProfile();
              },
            ),
          ));
        }
      } else {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Envoi impossible. R\u00e9essaie.')),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCompose = widget.conversation.isMatch;
    final myId =
        AppScope.of(context).currentUser?['id']?.toString() ?? '';
    final totalMessages = _messages.length;
    final startIndex =
      (totalMessages - ((_historyPage + 1) * _historyPageSize)).clamp(0, totalMessages);
    final visibleMessages = totalMessages == 0
      ? const <Map<String, dynamic>>[]
      : _messages.sublist(startIndex, totalMessages);
    final hasOlderMessages = startIndex > 0;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFF0F0F0),
                child: Text(
                  widget.conversation.otherName.isNotEmpty
                      ? widget.conversation.otherName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.conversation.otherName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                size: 40),
                            const SizedBox(height: 8),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _loadMessages,
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('R\u00e9essayer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _messages.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Vous avez matché. Démarrez la conversation en envoyant un message.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                        )
                      : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: visibleMessages.length + (hasOlderMessages ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (hasOlderMessages && i == 0) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Center(
                              child: OutlinedButton.icon(
                                onPressed: () => setState(() => _historyPage += 1),
                                icon: const Icon(Icons.history_rounded),
                                label: Text('Charger plus anciens ($startIndex)'),
                              ),
                            ),
                          );
                        }

                        final messageIndex = hasOlderMessages ? i - 1 : i;
                        final m = visibleMessages[messageIndex];
                        final isMe =
                            (m['senderId']?.toString() ?? '') == myId;
                        return _MessageBubble(
                          text: m['content']?.toString() ?? '',
                          time: m['createdAt']?.toString() ?? '',
                          isMe: isMe,
                        );
                      },
                    ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!canCompose)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFE082)),
                  ),
                  child: const Text(
                    'Envoi indisponible: match mutuel requis.',
                    style: TextStyle(
                      color: Color(0xFF8D6E63),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composer,
                      enabled: canCompose && !_isSending,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: canCompose
                            ? '\u00c9crire un message\u2026'
                            : 'Match requis pour discuter',
                        filled: true,
                        fillColor: const Color(0xFFF5F5F5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: (canCompose && !_isSending) ? _sendMessage : null,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.send_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.time,
    required this.isMe,
  });

  final String text;
  final String time;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(time);
    final timeLabel = parsed != null
        ? '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}'
        : time;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? Theme.of(context).colorScheme.primary
              : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: TextStyle(
                fontSize: 11,
                color: isMe ? Colors.white70 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
