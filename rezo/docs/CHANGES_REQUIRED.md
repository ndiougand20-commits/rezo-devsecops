# CHANGES REQUIRED — Alignement REZO avec la spécification produit

> Analyse comparative complète entre l'état actuel du backend (`C:\dev\backend`) et du frontend Flutter (`C:\dev\rezo`) face à la spécification REZO 4 rôles.
>
> **Rôles cibles :** Étudiant · Lycéen · Université/École de formation · Entreprise

---

## Table des matières

1. [Vue d'ensemble des écarts](#1-vue-densemble-des-écarts)
2. [Backend — Changements requis](#2-backend--changements-requis)
3. [Frontend Flutter — Changements requis](#3-frontend-flutter--changements-requis)
4. [Détail par rôle](#4-détail-par-rôle)
5. [Priorités de livraison](#5-priorités-de-livraison)

---

## 1. Vue d'ensemble des écarts

| Zone | Problème principal |
|------|-------------------|
| Rôle `EMPLOI` | Existe dans le code (backend + frontend) mais absent de la spec produit finale → à supprimer |
| Matching Lycéen | L'endpoint `/api/match/school-recommendations` est appelé côté Flutter mais **n'existe pas** dans le backend |
| Matching École / Entreprise | Ces rôles voient des offres à swiper alors qu'ils devraient swiper des **profils d'étudiants** |
| Système de match mutuel | Aucune logique de match mutuel (double LIKE) n'est implémentée ni côté backend ni côté frontend |
| Messagerie | Accessible sans condition de match mutuel — la spec exige que les messages soient limités aux paires qui ont matché |
| Offres — PDF/Brochure | Pas de champ ni d'upload de PDF pour une offre ou une formation |
| Profil — Documents par rôle | L'upload de médias existe mais sans distinction CV / LM / Bulletin / Justificatif reconn. diplôme par rôle |
| Dashboard — stats réelles | Les cartes de statistiques affichent des valeurs fictives (matchCount, likeCount…) |
| SupportIA | L'onglet IA est entièrement simulé localement ; aucun endpoint backend n'existe |
| Endpoints dev dangereux | `DELETE /api/auth/users` et `DELETE /api/auth/users/by-email/{email}` sont non protégés |

---

## 2. Backend — Changements requis

### 2.1 Suppression du rôle `EMPLOI`

**Fichiers concernés :** `UserRole.java`, `PackRules.java`, `AuthController.java`, `MatchController.java`

- Supprimer la valeur `EMPLOI` de l'enum `UserRole`.
- Dans `PackRules.isCandidateRole()` : retirer `UserRole.EMPLOI`.
- Dans `AuthController.parseRole()` : supprimer le cas `"EMPLOI"`.
- Dans `MatchController.scoreOffer()` / `buildSnapshot()` : supprimer toute référence à `EMPLOI`.

```java
// AVANT
public enum UserRole { ETUDIANT, LYCEEN, EMPLOI, ENTREPRISE, ECOLE, ADMIN }

// APRÈS
public enum UserRole { ETUDIANT, LYCEEN, ENTREPRISE, ECOLE, ADMIN }
```

---

### 2.2 Nouveau endpoint — Recommandations de formations pour Lycéen

**Fichier :** `MatchController.java` — ajouter `GET /api/match/school-recommendations`

Ce endpoint est déjà **appelé par le frontend** (`/api/match/school-recommendations`) mais **n'existe pas** dans le backend.

**Logique attendue :**
- Authentification requise, rôle `LYCEEN` seulement.
- Charger toutes les offres de type `FORMATION` (ownerEcole non null).
- Scorer en croisant `centresInteret` du lycéen avec `domaines` de l'école, et `objectifPostbac` avec `diplomesDelivres`.
- Exclure les offres déjà swipées (sauf si `includeSwiped=true`).
- Retourner le même format `MatchRecommendationsResponse` que le endpoint principal.
- Accepter optionnellement `?secteur=Informatique` pour filtrer par domaine.

```java
@GetMapping("/school-recommendations")
@Transactional
public ResponseEntity<?> getSchoolRecommendations(
    Principal principal,
    @RequestParam(name = "includeSwiped", defaultValue = "false") boolean includeSwiped,
    @RequestParam(name = "secteur", required = false) String secteur
) { ... }
```

---

### 2.3 Matching par profils — pour École et Entreprise

Actuellement, le matching ne supporte que `User → Offer`. La spec exige qu'École et Entreprise puissent swiper des **profils de candidats**.

#### 2.3.1 Nouveau endpoint — `GET /api/match/profile-recommendations`

- Accessible uniquement aux rôles `ECOLE` et `ENTREPRISE`.
- Pour **ENTREPRISE** : retourne des profils `ETUDIANT` dont le `domaine` / `competences` correspondent au `secteurActivite` de l'entreprise.
- Pour **ECOLE** : retourne des profils `ETUDIANT` + `LYCEEN` dont les `preferencesSecteur` / `centresInteret` correspondent aux `domaines` de l'école.
- Inclure dans chaque item : `userId`, `prenom`, `nom`, `avatarUrl`, `niveauEtude`, `domaine`, `competences`, `mediaFiles` (CV, diplômes), `score`.
- Pagination optionnelle.

#### 2.3.2 Nouvelle entité — `ProfileSwipe`

```java
@Entity
@Table(name = "profile_swipes", uniqueConstraints = {
    @UniqueConstraint(name = "uk_profile_swipe", columnNames = {"swiper_id", "target_user_id"})
})
public class ProfileSwipe {
    private UUID id;
    private User swiper;           // l'école ou l'entreprise
    private User targetUser;       // l'étudiant/lycéen
    private SwipeAction action;    // LIKE | DISLIKE
    private LocalDateTime createdAt;
}
```

#### 2.3.3 Nouveau endpoint — `POST /api/match/profile-swipe`

```json
{ "targetUserId": "uuid", "action": "LIKE" }
```

---

### 2.4 Logique de match mutuel

Un **match** = l'étudiant a LIKE une offre de l'entreprise/école **ET** l'entreprise/école a LIKE le profil de cet étudiant.

#### 2.4.1 Nouveau endpoint — `GET /api/match/mutual`

- Retourne la liste des matches mutuels de l'utilisateur connecté.
- Chaque item : `{ matchedUserId, matchedUserName, avatarUrl, offerTitre, matchedAt }`.

#### 2.4.2 Exposer `matchCount` dans `/api/users/me`

- Ajouter `matchCount` (nombre de matches mutuels actifs) dans la réponse `UserMeResponse`.

```java
// UserMeResponse — ajouter :
private long matchCount;
```

#### 2.4.3 Restreindre la messagerie aux paires matchées

Dans `MessageController.sendMessage()`, après vérification du pack, vérifier qu'il existe un match mutuel entre `sender` et `receiver` (sauf ADMIN).

---

### 2.5 Médias des offres — PDF/Brochure

**Fichiers :** `Offer.java`, `OfferController.java`, `OfferRequest.java`, `OfferResponse.java`

- Ajouter un champ `pdfUrl` (nullable) à l'entité `Offer` :

```java
@Column(length = 500)
private String pdfUrl;
```

- Ajouter `pdfUrl` dans `OfferRequest` et `OfferResponse`.
- Nouveau endpoint : `POST /api/offers/{id}/media` pour uploader un PDF (brochure/fiche de poste) et mettre à jour `pdfUrl`.

---

### 2.6 Catégories standardisées pour UserMediaFile

**Fichier :** `UserMediaController.java`

Définir des catégories valides et valider à l'upload :

| Catégorie | Qui peut uploader | Type MIME autorisé |
|-----------|------------------|--------------------|
| `PHOTO` | Tous | image/* |
| `CV` | ETUDIANT | application/pdf |
| `LM` | ETUDIANT | application/pdf |
| `DIPLOME` | ETUDIANT | application/pdf |
| `BULLETIN` | LYCEEN | application/pdf |
| `JUSTIFICATIF_RECONN` | ECOLE | application/pdf |
| `JUSTIFICATIF_ENTREPRISE` | ENTREPRISE | application/pdf |
| `OFFER_BROCHURE` | ECOLE, ENTREPRISE | application/pdf |

Ajouter une validation dans `uploadJustificatif()` :

```java
private static final Set<String> VALID_CATEGORIES = Set.of(
    "CV", "LM", "DIPLOME", "BULLETIN", "JUSTIFICATIF_RECONN",
    "JUSTIFICATIF_ENTREPRISE", "OFFER_BROCHURE"
);
```

---

### 2.7 Nouveau endpoint — Chat IA (Support)

L'entité `ChatSupport` existe mais aucun controller HTTP ne l'expose. L'onglet frontend est entièrement simulé.

**Créer `ChatSupportController.java`** avec :

- `POST /api/chat` — envoie un message, retourne la réponse IA.
  - Body : `{ "message": "...", "sessionId": "uuid", "context": "..." }`
  - Response : `{ "userMessage": "...", "iaResponse": "...", "sessionId": "uuid" }`
- `GET /api/chat/history?sessionId={uuid}` — retourne l'historique de la session.
- Intégrer un appel réel à une API IA (OpenAI, Mistral, etc.) ou conserver une réponse simulée avec un TODO clair.

---

### 2.8 Endpoint stats dashboard

**Fichier :** `UserController.java` ou nouveau `StatsController.java`

Nouveau endpoint `GET /api/users/me/stats` :

```json
{
  "matchCount": 3,
  "likesSent": 12,
  "likesReceived": 5,
  "offerCount": 2,
  "unreadMessages": 1
}
```

---

### 2.9 Sécurisation des endpoints de suppression en masse

**Fichier :** `AuthController.java`

- `DELETE /api/auth/users` — doit être conditionné à un profil Spring `dev` uniquement (`@Profile("dev")`), ou supprimé.
- `DELETE /api/auth/users/by-email/{email}` — même traitement.

```java
@Profile("dev")  // ← ajouter
@DeleteMapping("/users")
public ResponseEntity<?> deleteAllUsers() { ... }
```

---

### 2.10 Unification des endpoints Feature Access

**Fichier :** `FeatureAccessController.java`

Le frontend appelle `getFeatureAccess()` qui attend un objet unifié :

```json
{
  "messaging": { "allowed": true, "reason": null },
  "chat-ai": { "allowed": false, "reason": "Pack insuffisant", "requiredPack": "Premium" }
}
```

Le backend expose actuellement deux endpoints séparés (`/api/features/messaging/access` et `/api/features/chat-ai/access`). Vérifier comment le frontend consolide ces appels et s'assurer que l'endpoint `/api/features/access-summary` retourne exactement ce format.

```java
// GET /api/features/access-summary — modifier la réponse :
return ResponseEntity.ok(Map.of(
    "messaging", Map.of("allowed", PackRules.canUseMessaging(user), "reason", ...),
    "chat-ai",   Map.of("allowed", PackRules.canUseAiChat(user),    "reason", ...)
));
```

---

### 2.11 Matching — Filtrage par secteur pour Lycéen

Dans le futur endpoint `GET /api/match/school-recommendations`, supporter :

```
GET /api/match/school-recommendations?secteur=Informatique
```

Filtrer les offres de formation dont le `domaine` correspond au secteur demandé.

---

## 3. Frontend Flutter — Changements requis

### 3.1 Suppression du rôle `emploi`

**Fichiers :** `auth_flow.dart`, `signup_screen.dart`, `matches_tab.dart`, `home_tab.dart`

- Supprimer `UserRole.emploi` de l'enum.
- Supprimer tous les `case UserRole.emploi:` dans `apiValue`, `parseUserRole`, les switch expressions, `_buildHighlights()`, `_buildEmptyMessage()`.
- Supprimer la section de formulaire `emploi` dans `SignupScreen._buildPayload()`.
- Supprimer le cas `emploi` de `_buildTabs()`.

```dart
// AVANT
enum UserRole { etudiant, lyceen, emploi, entreprise, ecole }

// APRÈS
enum UserRole { etudiant, lyceen, entreprise, ecole }
```

---

### 3.2 Écran de sélection du rôle — WelcomeScreen

**Fichier :** fichier du welcome screen (à identifier)

- Afficher exactement 4 rôles : **Étudiant**, **Lycéen**, **Université/École de formation**, **Entreprise**.
- Supprimer l'option "En recherche d'emploi" (liée à `emploi`).

---

### 3.3 MatchesTab — Profils pour École et Entreprise

**Fichier :** `matches_tab.dart`

Actuellement, tous les rôles voient des offres à swiper. La spec exige que `ecole` et `entreprise` voient des **profils de candidats**.

#### 3.3.1 Nouveau flux pour `ecole` / `entreprise`

Dans `_loadRecommendations()` :

```dart
} else if (role == UserRole.ecole || role == UserRole.entreprise) {
  final data = await appState.fetchProfileRecommendations();
  mapped = _mapProfileRecommendations(data);
  // ...
} else {
  // étudiant : fetchRecommendations() existant
}
```

#### 3.3.2 Nouveau `_mapProfileRecommendations()`

Chaque carte affiche :
- Photo de profil (`avatarUrl`)
- Nom, prénom
- Niveau d'étude / domaine (étudiant) ou classe / série (lycéen)
- Compétences (tags)
- Badge "CV disponible" / "Bulletins disponibles" si médias présents
- Score de correspondance

#### 3.3.3 Nouveaux appels de service

Dans `services.dart` — ajouter dans l'interface `AuthService` :

```dart
Future<Map<String, dynamic>> fetchProfileRecommendations();
Future<Map<String, dynamic>> recordProfileSwipe({
  required String targetUserId,
  required String action, // "LIKE" | "DISLIKE"
});
```

Dans `HttpAuthService` : appeler `GET /api/match/profile-recommendations` et `POST /api/match/profile-swipe`.

Dans `state.dart` : exposer `fetchProfileRecommendations()` et `recordProfileSwipe()`.

---

### 3.4 MatchesTab — Corrections pour Lycéen

**Fichier :** `matches_tab.dart`

- Le backend doit créer `/api/match/school-recommendations` (voir §2.2) avant que cette partie fonctionne.
- Ajouter des **chips de filtre par secteur** au-dessus de la pile de cartes :
  - Informatique · Médecine · Droit · Commerce · Ingénierie · Arts · Sciences
- Passer le secteur sélectionné à `fetchSchoolRecommendations(secteur: _selectedSecteur)`.
- Dans `_mapSchoolRecommendations()` : corriger les caractères corrompus (`â€"` → `—`, `Ã‰` → `É`) dans les labels type/owner/location.

---

### 3.5 MatchesTab — Logique de replay pour Lycéen

**Fichier :** `matches_tab.dart`

- La méthode `_canReplay()` retourne `false` pour `lyceen` car `fetchSchoolRecommendations` ne supporte pas encore `includeSwiped`.
- Une fois le backend mis à jour (§2.2), passer `includeSwiped: true` à `fetchSchoolRecommendations`.

---

### 3.6 MessagesTab — Filtrage par match mutuel

**Fichier :** `messages_tab.dart`

- Après chargement des conversations, filtrer / indiquer celles qui correspondent à un match mutuel.
- Ajouter un appel à `GET /api/match/mutual` pour récupérer les paires matchées.
- Les conversations hors match mutuel doivent être grisées ou cachées selon la spec.
- Ajouter un badge "Match" sur les conversations matchées.

---

### 3.7 OffersTab — Upload PDF/Brochure

**Fichier :** `offers_tab.dart`

Dans le formulaire `_OfferFormSheet` :
- Ajouter un bouton "Joindre un PDF" (brochure de formation pour École, fiche de poste pour Entreprise).
- Utiliser `FilePicker` (ou `file_picker` package) pour sélectionner un PDF.
- Uploader via `POST /api/offers/{id}/media` après création/modification de l'offre.
- Afficher une vignette "📄 PDF joint" si un PDF existe déjà.

---

### 3.8 ProfileTab — Documents par rôle

**Fichier :** `profile_tab.dart`

Remplacer la section générique "Mes documents" par des sections spécifiques au rôle :

#### Étudiant
- Section **CV** : upload d'un PDF (catégorie `CV`), remplace le précédent.
- Section **Lettre de motivation** : upload d'un PDF (catégorie `LM`).
- Section **Justificatifs de diplômes** : liste de PDFs (catégorie `DIPLOME`), multi-upload.

#### Lycéen
- Section **Bulletins scolaires** : liste de PDFs (catégorie `BULLETIN`), multi-upload.
- Section **Justificatifs divers** : PDFs (catégorie `JUSTIFICATIF_RECONN`).

#### École
- Section **Justificatifs de reconnaissance** : PDFs prouvant l'accréditation (catégorie `JUSTIFICATIF_RECONN`).
- Section **Photo de l'établissement** : image (catégorie `PHOTO`), remplace l'actuel `logoUrl` si uploadée.

#### Entreprise
- Section **Justificatifs d'entreprise** : PDFs (KBIS, etc.) (catégorie `JUSTIFICATIF_ENTREPRISE`).
- Section **Photo/Logo entreprise** : image (catégorie `PHOTO`).

**Dans le code :**
- Ajouter un helper `_buildDocSection(String title, String category, bool multiUpload)` dans `_ProfileTabState`.
- Filtrer `_mediaFiles` par `category` pour chaque section.
- Appeler `appState.uploadJustificatifPdf(bytes, fileName)` avec la catégorie appropriée (ajouter `category` comme paramètre dans `uploadJustificatifPdf`).

---

### 3.9 HomeTab (Dashboard) — Statistiques réelles

**Fichier :** `home_tab.dart`

- Appeler `GET /api/users/me/stats` (nouveau endpoint §2.8) dans `_loadDynamicData()`.
- Remplacer les valeurs fictives des `_StatCard` par les vraies valeurs : `matchCount`, `likesReceived`, `unreadMessages`.
- Pour `ecole` et `entreprise` : afficher aussi `offerCount`.

```dart
// Dans _loadDynamicData() :
final stats = await appState.fetchMyStats();
setState(() {
  _matchCount = stats['matchCount'] ?? 0;
  _likeCount = stats['likesReceived'] ?? 0;
  _unreadMessages = stats['unreadMessages'] ?? 0;
});
```

---

### 3.10 AiChatTab — Connexion au backend réel

**Fichier :** `ai_chat_tab.dart`

- Remplacer la simulation locale par un vrai appel API.
- Dans `_AiChatTabState._sendMessage()` : appeler `POST /api/chat` (endpoint §2.7).
- Garder le fallback local SharedPreferences pour le cache de l'historique.
- Ajouter `sendChatMessage()` dans `AuthService` et `HttpAuthService`.

```dart
// Dans AuthService :
Future<Map<String, dynamic>> sendChatMessage({
  required String message,
  required String sessionId,
  String? context,
});
```

---

### 3.11 Signup — Suppression du rôle `emploi`

**Fichier :** `signup_screen.dart`

- Retirer le `case UserRole.emploi` dans `_buildPayload()`.
- Retirer les controllers spécifiques à `emploi` (`_niveauEtudeController` etc. restent pour `etudiant`).
- S'assurer que les 4 options de rôle dans le sélecteur correspondent à la spec.

---

### 3.12 Services — Nouveaux appels

**Fichier :** `services.dart`

Ajouter dans l'interface `AuthService` et dans `HttpAuthService` :

```dart
// Matching profils (école / entreprise)
Future<Map<String, dynamic>> fetchProfileRecommendations();
Future<Map<String, dynamic>> recordProfileSwipe({
  required String targetUserId,
  required String action,
});

// Matches mutuels
Future<List<Map<String, dynamic>>> fetchMutualMatches();

// Stats
Future<Map<String, dynamic>> fetchMyStats();

// Chat IA
Future<Map<String, dynamic>> sendChatMessage({
  required String message,
  required String sessionId,
  String? context,
});

// Recommandations formations avec filtre secteur
@override
Future<Map<String, dynamic>> fetchSchoolRecommendations({String? secteur});
```

---

## 4. Détail par rôle

### 4.1 Étudiant

| Page | État actuel | Changements requis |
|------|-------------|-------------------|
| Dashboard | Hero card + chips, stats fictives | Brancher les vraies stats (matchCount, likes, messages) |
| Messages | Affiche toutes les conversations | Filtrer aux conversations avec match mutuel |
| Matching | Swipe sur offres emploi + formations ✓ | Vérifier que le filtrage role=ETUDIANT fonctionne côté backend |
| SupportIA | Simulé localement | Connecter à `POST /api/chat` |
| Profil | Infos de base + pack | Ajouter sections CV, LM, Justificatifs diplômes |

### 4.2 Lycéen

| Page | État actuel | Changements requis |
|------|-------------|-------------------|
| Dashboard | Générique | Adapter les highlights au rôle lycéen |
| Messages | Affiche toutes les conversations | Filtrer aux conversations avec match mutuel |
| Matching | Appelle un endpoint inexistant | **Créer** `/api/match/school-recommendations` backend + ajouter filtre secteur frontend |
| SupportIA | Simulé localement | Connecter à `POST /api/chat` |
| Profil | Infos de base + pack | Ajouter sections Bulletins scolaires, Justificatifs |

### 4.3 Université / École de formation

| Page | État actuel | Changements requis |
|------|-------------|-------------------|
| Dashboard | Générique | Stats réelles : nombre d'offres, matchCount, likes reçus |
| Messages | Affiche toutes les conversations | Filtrer aux paires matchées |
| Matching | Swipe sur offres (incorrect) | Swipe sur **profils étudiants/lycéens** via nouveau endpoint |
| SupportIA | Simulé localement | Connecter à `POST /api/chat` |
| Offres | CRUD offres formations ✓ | Ajouter upload PDF/Brochure par offre |
| Profil | Fiche école modifiable ✓ | Ajouter section Justificatifs de reconnaissance, photo établissement |

### 4.4 Entreprise

| Page | État actuel | Changements requis |
|------|-------------|-------------------|
| Dashboard | Générique | Stats réelles : offres publiées, matchCount, likes reçus |
| Messages | Affiche toutes les conversations | Filtrer aux paires matchées |
| Matching | Swipe sur offres (incorrect) | Swipe sur **profils étudiants** via nouveau endpoint |
| SupportIA | Simulé localement | Connecter à `POST /api/chat` |
| Offres | CRUD offres emploi ✓ | Ajouter upload PDF (fiche de poste) par offre |
| Profil | Fiche entreprise modifiable ✓ | Ajouter section Justificatifs (KBIS, etc.), photo entreprise |

---

## 5. Priorités de livraison

### 🔴 Critique (bloquant fonctionnellement)

1. **Backend** : Créer `GET /api/match/school-recommendations` → la page Matching du Lycéen est complètement cassée
2. **Backend + Frontend** : Créer le matching par profils pour École/Entreprise (`GET /api/match/profile-recommendations` + `POST /api/match/profile-swipe`)
3. **Backend + Frontend** : Supprimer le rôle `EMPLOI` partout

### 🟠 Important (spec non respectée)

4. **Backend** : Implémenter la logique de match mutuel (`GET /api/match/mutual` + `matchCount` dans `/me`)
5. **Frontend** : Filtrer la messagerie aux paires matchées
6. **Backend** : Créer `GET /api/users/me/stats`
7. **Frontend** : Brancher les vraies stats dans le Dashboard

### 🟡 Améliorations significatives

8. **Backend + Frontend** : Upload PDF par offre (brochure / fiche de poste)
9. **Frontend** : Sections de documents par rôle dans le Profil
10. **Backend** : Standardiser et valider les catégories de `UserMediaFile`
11. **Backend** : Unifier l'endpoint `/api/features/access-summary` pour correspondre au format attendu par le frontend

### 🟢 Non bloquant

12. **Backend + Frontend** : Connecter le Chat IA au backend réel (`POST /api/chat`)
13. **Frontend** : Filtre par secteur dans le Matching Lycéen
14. **Backend** : Sécuriser ou supprimer les endpoints `DELETE /api/auth/users` en production
15. **Frontend** : Corriger les caractères UTF-8 corrompus dans `_mapOfferRecommendations()` (`â€"` → `—`)

---

*Document généré le 2025-07-09 — à mettre à jour au fur et à mesure des livraisons.*
