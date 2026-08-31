# TODO Integration Frontend REZO

> Cocher chaque case au fur et a mesure de l'implementation.
> Derniere mise a jour : **05 mai 2026**

---

## Legende des priorites

| Symbole | Signification |
|---|---|
| 1 | **Bloquant** — l'app est partiellement cassee ou ne compile pas |
| 2 | **Important** — fonctionnalite coeur du cahier des charges |
| 3 | **Amelioration** — necessaire pour une v1 complete et coherente |

---

## Reference rapide — endpoints backend disponibles

| Methode | Route | Auth | Pack requis |
|---|---|---|---|
| POST | `/api/auth/signup` | — | — |
| POST | `/api/auth/login` | — | — |
| GET | `/api/users/me` | JWT | — |
| PUT | `/api/users/me` | JWT | — |
| DELETE | `/api/users/me` | JWT | — |
| PUT/PATCH | `/api/users/me/pack` | JWT | — |
| GET | `/api/users/me/media` | JWT | — |
| POST | `/api/users/me/media/photos` | JWT | — |
| POST | `/api/users/me/media/justificatifs` | JWT | — |
| GET | `/api/users/{id}` | JWT | — |
| GET | `/api/messages` | JWT | — |
| POST | `/api/messages` | JWT | — |
| PUT | `/api/messages/{id}` | JWT | — |
| DELETE | `/api/messages/{id}` | JWT | — |
| GET | `/api/conversations` | JWT | — |
| POST | `/api/conversations` | JWT | — |
| GET | `/api/offers` | JWT | — |
| POST | `/api/offers` | JWT | PROFESSIONNEL |
| PUT | `/api/offers/{id}` | JWT | PROFESSIONNEL |
| DELETE | `/api/offers/{id}` | JWT | PROFESSIONNEL |
| POST | `/api/offers/{id}/like` | JWT | — |
| GET | `/api/matching/recommendations` | JWT | — |
| POST | `/api/matching/swipe` | JWT | — |
| GET | `/api/features/{feature}/access` | JWT | — |

---

## Groupe 1 — Onboarding / accueil

- [x] **1.1** Ecran splash avec logo REZO et animation de chargement
- [x] **1.2** Ecran welcome avec CTA "Se connecter" et "Creer un compte"
- [x] **1.3** Onboarding slides (3 slides : matching, messagerie, IA)
- [x] **1.4** Navigation Welcome -> Onboarding -> Login/Signup

---

## Groupe 2 — Authentification

- [x] **2.1** Ecran Login (email + mot de passe, gestion erreurs, loader)
- [x] **2.2** Ecran Signup multi-profils (ETUDIANT, ENTREPRISE, ECOLE) avec formulaire dynamique
- [x] **2.3** Stockage JWT via `flutter_secure_storage`
- [x] **2.4** Restauration de session au lancement via `GET /api/users/me`
- [x] **2.5** Logout (suppression token + redirection)

---

## Groupe 3 — Architecture et services

- [x] **3.1** `AuthService` abstrait avec `HttpAuthService` concret
- [x] **3.2** `TokenStorage` abstrait avec `SecureTokenStorage` et `MemoryTokenStorage`
- [x] **3.3** `AppState` avec `restoreSession`, `login`, `signup`, `logout`
- [x] **3.4** `AppScope` (InheritedNotifier) pour acces global a `AppState`

---

## Groupe 4 — Dashboard principal

- [x] **4.1** `DashboardScreen` avec `NavigationBar` multi-onglets
- [x] **4.2** Onglet Accueil (`home_tab.dart`)
- [x] **4.3** Onglet Messages (`messages_tab.dart`)
- [x] **4.4** Onglet Matching (`matches_tab.dart`)
- [x] **4.5** Onglet Profil (`profile_tab.dart`)

---

## Groupe 5 — Profil utilisateur

- [x] **5.1** Afficher les informations du profil courant (`GET /api/users/me`)
- [x] **5.1.4** Si `statusCode == 401` : appeler `AppScope.of(context).logout()`
- [x] **5.2** Formulaire d'edition du profil selon le role (`PUT /api/users/me`)
- [x] **5.2.3** `_MockMatch` renommee en `_MatchItem` dans `matches_tab.dart`
- [x] **5.3** Upload photo de profil (`POST /api/users/me/media/photos`)
- [x] **5.4** Selecteur de pack (`PUT /api/users/me/pack`)
- [x] **5.5** Afficher les champs specifiques selon le role
- [x] **5.5.2** Lien vers site web de l'ecole/entreprise
- [x] **5.5.3** Pour LYCEEN : afficher `diplomesDelivres[]`, `siteWeb`, `adresse`

---

## Groupe 6 — Messagerie

- [x] **6.1** Liste des conversations (`GET /api/conversations`)
- [x] **6.2** Ecran detail conversation avec liste de messages
- [x] **6.3** Envoi de message (`POST /api/messages`)
- [x] **6.4** Marquage lu/non-lu

---

## Groupe 7 — Matching / Swipe

- [x] **7.1** Cards de recommandations (`GET /api/matching/recommendations`)
- [x] **7.2** Swipe Like/Pass (`POST /api/matching/swipe`)
- [x] **7.3** Animation de swipe (GestureDetector + Transform)
- [x] **7.4** Ecran "Aucune recommandation disponible"

---

## Groupe 8 — Offres (ECOLE / ENTREPRISE)

> **Fichier** : `lib/features/auth/offers_tab.dart`

- [x] **8.1** Lister les offres de l'utilisateur (`GET /api/offers` filtre `ownerUserId`)
- [x] **8.2** Creer une offre (`POST /api/offers`) via formulaire : titre, description, type (STAGE/EMPLOI/FORMATION), domaine, lieu, competences, dates
- [x] **8.3** Modifier une offre (`PUT /api/offers/{id}`)
- [x] **8.4** Supprimer une offre (`DELETE /api/offers/{id}`)
- [x] **8.5** Afficher les utilisateurs ayant like l'offre (`_LikedByList` DraggableScrollableSheet)
- [x] **8.6** Afficher un etat "pack insuffisant" si `canManageOffers == false` — Message : `"Votre pack actuel ne permet pas de publier des offres"` — Bouton "Voir les packs" -> onglet Profil > selecteur de pack

---

## Groupe 9 — Navigation adaptative (`dashboard_screen.dart`)

> **Fichier** : `lib/features/auth/dashboard_screen.dart`

- [x] **9.1** Ajouter un 5eme onglet "Mes offres" dans `NavigationBar` visible **uniquement** si `role == ECOLE || role == ENTREPRISE` — Icone : `Icons.work_outline_rounded` — Tab widget : `_OffersTab`
- [x] **9.2** Ajouter un onglet "Chat IA" visible uniquement si `currentUser['canUseAiChat'] == true` — Icone : `Icons.auto_awesome_rounded`
- [x] **9.3** Recalculer les indices de `selectedIndex` dynamiquement pour eviter les index out-of-bounds

---

## Groupe 10 — `home_tab.dart` — dashboard dynamique

> **Fichier** : `lib/features/auth/home_tab.dart`

- [x] **10.1** Charger `getFeatureAccess()` au demarrage — masquer les cartes non autorisees — badge "Pack requis" sur les fonctionnalites bloquees
- [x] **10.2** Metriques reelles : nombre de messages non lus, nombre d'offres publiees
- [x] **10.3** Banniere "Complete ton profil" si des champs cles sont vides (selon le role)
- [x] **10.4** Afficher le nom et le niveau du pack actuel dans le header dashboard

---

## Groupe 11 — Chat IA

> **Nouveau fichier** : `lib/features/auth/ai_chat_tab.dart`
> Le backend ne possede **pas encore** d'endpoint IA. Cette integration est en attente.

- [x] **11.1** Verifier l'acces via `GET /api/features/chat-ai/access` — Si `allowed == false` : ecran "Upgrade" avec nom du pack requis et CTA vers selecteur
- [x] **11.2** Interface de chat : bulles scrollable (IA a gauche, utilisateur a droite), TextField + bouton envoi, indicateur de frappe 3 points animes
- [x] **11.3** Historique local (SharedPreferences) — cle : `ai_chat_history_${userId}`
- [x] **11.4** Simulation de reponse IA (900ms de delai) en attendant l'endpoint backend

---

## Groupe 12 — UX transverse

- [x] **12.1** Helper `handleAuthError(BuildContext, AuthException)` dans `widgets.dart`
- [x] **12.2** `SocketException` -> `AuthException('Pas de connexion internet')` via wrappers `_httpGet/Post/Put/Patch/Delete` dans `services.dart`
- [x] **12.3** `RefreshIndicator` sur tous les `ListView` principaux (messages, matches, offres, profil)
- [x] **12.4** Skeleton loaders (`SkeletonBox`, `SkeletonList`) dans `widgets.dart`
- [x] **12.5** Helpers `formatDate(DateTime, {bool withTime})` et `formatRelativeDate(DateTime)` dans `widgets.dart`

---

## Etat final

**Tous les groupes G1 -> G12 sont completes. 0 item restant.**
