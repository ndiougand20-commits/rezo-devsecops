part of 'auth_flow.dart';

// ---------------------------------------------------------------------------
// Report Tab
// ---------------------------------------------------------------------------

class _ReportTab extends StatefulWidget {
  const _ReportTab({required this.role, super.key});
  final UserRole role;
  @override
  State<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<_ReportTab> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = const <String, dynamic>{};
  DateTime? _lastRefreshAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final stats = await AppScope.of(context).fetchMyStats();
      if (!mounted) return;
      setState(() { _stats = stats; _lastRefreshAt = DateTime.now(); _loading = false; });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Impossible de charger les rapports. Verifiez votre connexion.'; _loading = false; });
    }
  }

  int _n(String key) => (_stats[key] as num?)?.toInt() ?? 0;

  double _rate(int numerator, int denominator) =>
      denominator <= 0 ? 0.0 : (numerator / denominator).clamp(0.0, 1.0);

  String _pct(int numerator, int denominator) {
    if (denominator <= 0) return '0 %';
    return '${((numerator / denominator) * 100).round()} %';
  }

  String _lastRefreshLabel() {
    final ts = _lastRefreshAt;
    if (ts == null) return 'Mise a jour en attente';
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    return 'Derniere mise a jour a $hh:$mm';
  }

  int _activityScore(int matchCount, int likesSent, int likesReceived, int unreadMessages, int offerCount) {
    int score = 0;
    score += (matchCount * 20).clamp(0, 40);
    score += (likesSent * 5).clamp(0, 20);
    score += (likesReceived * 5).clamp(0, 20);
    if (unreadMessages == 0) score += 10;
    if (offerCount > 0) score += 10;
    return score.clamp(0, 100);
  }

  String _roleIntro(UserRole role) {
    switch (role) {
      case UserRole.etudiant:
        return 'Ce rapport mesure ton activite en tant qu\'etudiant sur REZO : likes envoyes aux offres, correspondances mutuelles (matchs), messages recus et ton taux de conversion global.';
      case UserRole.lyceen:
        return 'Ce rapport suit ta demarche de recherche de formation : combien d\'ecoles tu as contactees, combien ont repondu positivement, et tes echanges en cours.';
      case UserRole.entreprise:
        return 'Ce rapport mesure la performance de votre recrutement sur REZO : attractivite de vos offres, profils likes, matchs etablis avec des candidats, et reactivite a la messagerie.';
      case UserRole.ecole:
        return 'Ce rapport evalue votre visibilite aupres des candidats : interet suscite par vos formations, profils ayant matche avec votre ecole, et echanges en cours.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, height: 1.4)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final matchCount     = _n('matchCount');
    final likesReceived  = _n('likesReceived');
    final likesSent      = _n('likesSent');
    final unreadMessages = _n('unreadMessages');
    final offerCount     = _n('offerCount');
    final isRecruiter    = widget.role == UserRole.entreprise || widget.role == UserRole.ecole;

    final score      = _activityScore(matchCount, likesSent, likesReceived, unreadMessages, offerCount);
    final scoreLabel = score >= 70 ? 'Excellent' : score >= 40 ? 'Bon' : 'A ameliorer';
    final scoreColor = score >= 70 ? const Color(0xFF22C55E) : score >= 40 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);

    final cards = <_ReportCardData>[
      _ReportCardData(
        label: 'Matchs',
        value: '$matchCount',
        icon: Icons.favorite_rounded,
        accent: matchCount > 0 ? const Color(0xFF22C55E) : const Color(0xFFD1D5DB),
        helper: matchCount == 0
            ? 'Aucune correspondance mutuelle encore'
            : matchCount == 1 ? '1 connexion mutuelle etablie' : '$matchCount connexions mutuelles etablies',
        tooltip: 'Un match se produit quand tu aimes une offre ET que le recruteur/ecole a aussi like ton profil.',
      ),
      _ReportCardData(
        label: 'Likes recus',
        value: '$likesReceived',
        icon: Icons.thumb_up_alt_rounded,
        accent: likesReceived > 0 ? const Color(0xFF3B82F6) : const Color(0xFFD1D5DB),
        helper: likesReceived == 0
            ? 'Ton profil n\'a pas encore ete like'
            : 'Ton profil interesse $likesReceived recruteur${likesReceived > 1 ? 's' : ''}',
        tooltip: 'Nombre de fois ou un recruteur ou une ecole a like ton profil. Indique l\'attractivite de ton profil.',
      ),
      _ReportCardData(
        label: 'Messages non lus',
        value: '$unreadMessages',
        icon: Icons.mark_chat_unread_rounded,
        accent: unreadMessages == 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        helper: unreadMessages == 0
            ? 'Boite de reception a jour — aucun message en attente'
            : '$unreadMessages message${unreadMessages > 1 ? 's' : ''} en attente de ta reponse',
        tooltip: 'Messages recus que tu n\'as pas encore lus. Une reponse rapide augmente tes chances de matcher.',
      ),
      _ReportCardData(
        label: 'Likes envoyes',
        value: '$likesSent',
        icon: Icons.outbound_rounded,
        accent: likesSent > 0 ? const Color(0xFF8B5CF6) : const Color(0xFFD1D5DB),
        helper: likesSent == 0
            ? 'Tu n\'as encore like aucune opportunite'
            : 'Tu as prospecte $likesSent opportunite${likesSent > 1 ? 's' : ''}',
        tooltip: 'Nombre d\'offres ou de profils que tu as likes. Montre ton niveau de prospection actif.',
      ),
      if (isRecruiter)
        _ReportCardData(
          label: 'Offres publiees',
          value: '$offerCount',
          icon: Icons.work_rounded,
          accent: offerCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
          helper: offerCount == 0
              ? 'Aucune offre publiee — publiez pour attirer des candidats'
              : '$offerCount offre${offerCount > 1 ? 's' : ''} visible${offerCount > 1 ? 's' : ''} sur la plateforme',
          tooltip: 'Nombre d\'offres publiees. Sans offre, votre visibilite dans le matching est limitee.',
        ),
    ];

    final conversionRate = _pct(matchCount, likesSent);
    final attractRate    = _pct(likesReceived, likesSent + 1);
    final pendingRate    = _pct(unreadMessages, (unreadMessages + matchCount).clamp(1, 999999));

    final insights = <_InsightItem>[
      _InsightItem(
        title: 'Taux de conversion (likes → matchs)',
        detail: 'Sur $likesSent like${likesSent > 1 ? 's' : ''} envoye${likesSent > 1 ? 's' : ''}, $matchCount ont abouti a un match mutuel, soit $conversionRate de reussite. '
            '${matchCount == 0 && likesSent > 0 ? 'Essaie d\'affiner tes criteres ou de completer ton profil pour augmenter tes chances.' : matchCount > 0 ? 'C\'est un bon ratio — continue sur cette lancee.' : 'Commence a liker des offres pour generer des correspondances.'}',
        rate: _rate(matchCount, likesSent.clamp(1, 999999)),
        color: const Color(0xFF22C55E),
      ),
      _InsightItem(
        title: 'Attractivite du profil',
        detail: 'Tu as recu $likesReceived like${likesReceived > 1 ? 's' : ''} entrant${likesReceived > 1 ? 's' : ''} pour $likesSent envoye${likesSent > 1 ? 's' : ''} ($attractRate de retour). '
            '${likesReceived > likesSent ? 'Ton profil genere beaucoup d\'interet spontane : convertis ces signaux en echanges via la messagerie.' : likesReceived == 0 ? 'Complete ton profil (photo, competences, objectif) pour augmenter ta visibilite.' : 'Bon equilibre entre prospection et attractivite passive.'}',
        rate: _rate(likesReceived, (likesSent + 1).clamp(1, 999999)),
        color: const Color(0xFF3B82F6),
      ),
      _InsightItem(
        title: 'Reactivite messagerie',
        detail: unreadMessages == 0
            ? 'Aucun message en attente. Tu es reactif — c\'est un signal positif pour tes interlocuteurs et ameliore tes chances de progression vers un entretien ou une selection.'
            : '$unreadMessages message${unreadMessages > 1 ? 's' : ''} attend${unreadMessages > 1 ? 'ent' : ''} ta reponse ($pendingRate de tes conversations actives). Un delai de reponse eleve peut freiner l\'avancement de tes dossiers.',
        rate: unreadMessages == 0 ? 1.0 : (1.0 - _rate(unreadMessages, (unreadMessages + matchCount).clamp(1, 999999))),
        color: unreadMessages == 0 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
      ),
      if (isRecruiter)
        _InsightItem(
          title: 'Pipeline d\'offres',
          detail: offerCount == 0
              ? 'Aucune offre publiee. Sans offre active, votre profil est invisible pour les candidats dans le matching. Publiez au moins une offre pour demarrer le flux.'
              : '$offerCount offre${offerCount > 1 ? 's' : ''} publiee${offerCount > 1 ? 's' : ''} en ligne. Chaque offre augmente votre surface de contact avec les candidats pertinents.',
          rate: offerCount > 0 ? 1.0 : 0.0,
          color: offerCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
        ),
    ];

    final actions = <_ActionItem>[];
    if (unreadMessages > 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.urgent,
        title: 'Reponds a tes messages non lus ($unreadMessages)',
        detail: 'Des recruteurs ou candidats attendent une reponse de ta part. Plus tu tardes, plus tu risques de perdre l\'opportunite. Ouvre la messagerie et traite les conversations en attente.',
        icon: Icons.mark_chat_unread_rounded,
      ));
    }
    if (likesSent == 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.important,
        title: 'Lance ta prospection active',
        detail: 'Tu n\'as encore like aucune opportunite. Va dans l\'onglet Matching et swipe les offres ou profils qui correspondent a tes criteres. Plus tu likeras, plus tu augmenteras tes chances de match.',
        icon: Icons.explore_rounded,
      ));
    } else if (matchCount == 0 && likesSent > 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.important,
        title: 'Affine ton profil pour convertir tes likes',
        detail: 'Tu as envoye $likesSent like${likesSent > 1 ? 's' : ''} sans obtenir de match. Complete ton profil avec des competences precises, une photo et un objectif clair pour convaincre les recruteurs ou les ecoles.',
        icon: Icons.person_search_rounded,
      ));
    }
    if (isRecruiter && offerCount == 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.important,
        title: 'Publie ta premiere offre',
        detail: 'Sans offre publiee, votre profil est invisible pour les candidats dans le matching. Allez dans l\'onglet Offres et creez une offre de stage, d\'emploi ou de formation.',
        icon: Icons.post_add_rounded,
      ));
    }
    if (likesReceived > 0 && matchCount == 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.suggestion,
        title: 'Explore les profils qui t\'ont like',
        detail: '$likesReceived personne${likesReceived > 1 ? 's' : ''} a like ton profil sans match encore. Va dans l\'onglet Matching et swipe les profils entrants — un match mutuel debloquerait la messagerie.',
        icon: Icons.group_rounded,
      ));
    }
    if (isRecruiter && offerCount > 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.suggestion,
        title: 'Mets a jour tes offres publiees',
        detail: 'Garder tes offres a jour (date, description, competences requises) ameliore leur score dans l\'algorithme de matching et attire des profils plus pertinents.',
        icon: Icons.edit_note_rounded,
      ));
    }
    if (unreadMessages == 0 && likesSent > 0 && matchCount > 0) {
      actions.add(_ActionItem(
        priority: _ActionPriority.ok,
        title: 'Excellent rythme — continue sur cette lancee',
        detail: 'Tu es reactif, tu prospectes activement et tu generes des matchs. Maintiens cette cadence pour maximiser tes opportunites sur la plateforme.',
        icon: Icons.check_circle_rounded,
      ));
    }
    if (actions.isEmpty) {
      actions.add(_ActionItem(
        priority: _ActionPriority.ok,
        title: 'Profil actif — aucune alerte',
        detail: 'Tout semble en ordre pour l\'instant. Continue de visiter l\'onglet Matching regulierement et reponds rapidement aux messages pour rester dans les meilleurs profils.',
        icon: Icons.verified_rounded,
      ));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Rapport d\'activite',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              Tooltip(
                message: 'Actualiser',
                child: IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(_lastRefreshLabel(),
              style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.45))),
          const SizedBox(height: 8),

          // Intro contextuelle par role
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDE3F0)),
            ),
            child: Text(_roleIntro(widget.role),
                style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF374151))),
          ),
          const SizedBox(height: 14),

          // Score global
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE3E3E3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.speed_rounded, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Score d\'activite global',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(scoreLabel,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scoreColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF0F0F0),
                    valueColor: AlwaysStoppedAnimation(scoreColor),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Score : $score / 100  —  Calcule a partir de tes matchs, likes, messages lus et offres publiees.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Cartes metriques
          GridView.builder(
            itemCount: cards.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.02,
            ),
            itemBuilder: (_, i) => _ReportCard(data: cards[i]),
          ),
          const SizedBox(height: 14),

          // Indicateurs avances
          _SectionTitle(title: 'Indicateurs avances', icon: Icons.analytics_outlined),
          const SizedBox(height: 8),
          ...insights.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _InsightCard(item: item),
          )),
          const SizedBox(height: 4),

          // Actions recommandees
          _SectionTitle(title: 'Actions recommandees', icon: Icons.bolt_rounded),
          const SizedBox(height: 8),
          ...actions.map((a) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ActionCard(action: a),
          )),
          const SizedBox(height: 4),

          // Glossaire
          _ReportPanel(
            title: 'Glossaire des indicateurs',
            icon: Icons.info_outline_rounded,
            children: const [
              _ReportBullet(
                icon: Icons.favorite_rounded,
                text: 'Match — Une correspondance mutuelle : tu as like une offre ET l\'entite a like ton profil. C\'est le stade ou la messagerie devient accessible.',
              ),
              _ReportBullet(
                icon: Icons.thumb_up_alt_rounded,
                text: 'Likes recus — Nombre d\'entites (recruteurs, ecoles) qui ont trouve ton profil pertinent et l\'ont like. Un like recu ne cree pas encore un match.',
              ),
              _ReportBullet(
                icon: Icons.outbound_rounded,
                text: 'Likes envoyes — Nombre d\'offres ou profils que tu as likes. Indicateur de ton activite de prospection.',
              ),
              _ReportBullet(
                icon: Icons.mark_chat_unread_rounded,
                text: 'Messages non lus — Conversations recues auxquelles tu n\'as pas encore repondu. Une reactivite elevee favorise les opportunites.',
              ),
              _ReportBullet(
                icon: Icons.work_rounded,
                text: 'Offres publiees — (Entreprise/Ecole) Nombre d\'offres visibles sur la plateforme. Sans offre, votre profil ne remonte pas dans le matching.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.black87),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _ReportCardData {
  const _ReportCardData({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.helper,
    required this.tooltip,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final String helper;
  final String tooltip;
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.data});
  final _ReportCardData data;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: data.tooltip,
      preferBelow: false,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E2E2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: data.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, size: 18, color: data.accent),
            ),
            const Spacer(),
            Text(data.value,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: data.accent)),
            const SizedBox(height: 2),
            Text(data.label,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black54)),
            const SizedBox(height: 3),
            Text(data.helper,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Colors.black45, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _InsightItem {
  const _InsightItem({
    required this.title,
    required this.detail,
    required this.rate,
    required this.color,
  });
  final String title;
  final String detail;
  final double rate;
  final Color color;
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.item});
  final _InsightItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Text('${(item.rate * 100).round()} %',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: item.color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: item.rate,
              minHeight: 6,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation(item.color),
            ),
          ),
          const SizedBox(height: 8),
          Text(item.detail,
              style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF4B5563))),
        ],
      ),
    );
  }
}

enum _ActionPriority { urgent, important, suggestion, ok }

class _ActionItem {
  const _ActionItem({
    required this.priority,
    required this.title,
    required this.detail,
    required this.icon,
  });
  final _ActionPriority priority;
  final String title;
  final String detail;
  final IconData icon;
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.action});
  final _ActionItem action;

  static const _priorityColors = {
    _ActionPriority.urgent:     Color(0xFFEF4444),
    _ActionPriority.important:  Color(0xFFF59E0B),
    _ActionPriority.suggestion: Color(0xFF3B82F6),
    _ActionPriority.ok:         Color(0xFF22C55E),
  };

  static const _priorityLabels = {
    _ActionPriority.urgent:     'Urgent',
    _ActionPriority.important:  'Important',
    _ActionPriority.suggestion: 'Suggestion',
    _ActionPriority.ok:         'Tout va bien',
  };

  @override
  Widget build(BuildContext context) {
    final color = _priorityColors[action.priority]!;
    final label = _priorityLabels[action.priority]!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E3E3)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(action.icon, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(action.title,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(label,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(action.detail,
                    style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF4B5563))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportPanel extends StatelessWidget {
  const _ReportPanel({
    required this.title,
    required this.icon,
    required this.children,
  });
  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ReportBullet extends StatelessWidget {
  const _ReportBullet({required this.text, this.icon});
  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon ?? Icons.circle, size: icon != null ? 16 : 7, color: Colors.black45),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 12, height: 1.45, color: Color(0xFF374151))),
          ),
        ],
      ),
    );
  }
}
