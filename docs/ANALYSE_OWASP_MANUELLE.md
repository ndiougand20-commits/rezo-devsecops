# Analyse OWASP manuelle de Rezo

Date de l'analyse : 31/08/2026  
Périmètre : application Flutter et API Spring Boot  
Méthode : revue statique manuelle avant exécution des scanners

## Synthèse

La revue a identifié sept faiblesses démontrables. Elles ne sont pas introduites pour l'examen : elles existent dans la version importée du projet. Les protections déjà présentes (BCrypt, JWT signé, stockage sécurisé mobile, requêtes JPA, vérifications de propriété sur plusieurs contrôleurs et variables d'environnement) sont conservées dans l'évaluation.

| ID | Fichier et ligne | OWASP Top 10 2021 | CWE | Constat | Sévérité |
|---|---|---|---|---|---|
| RZ-01 | `backend/.../controller/KPIController.java:36-63` | A01 - Broken Access Control | CWE-862 | KPI, export CSV et remise à zéro accessibles à tout compte authentifié | Haute |
| RZ-02 | `backend/.../security/SecurityConfig.java:73-74` et `AuthController.java:213-275` | A01 - Broken Access Control | CWE-862 | En profil `dev`, tout compte authentifié peut supprimer tous les utilisateurs ou un compte choisi | Critique |
| RZ-03 | `backend/.../entities/RefreshToken.java:30-31` et `RefreshTokenService.java:33-39` | A02 - Cryptographic Failures | CWE-312 | Jetons de rafraîchissement persistés en clair | Haute |
| RZ-04 | `rezo/lib/features/auth/services.dart:126-142` | A02 - Cryptographic Failures | CWE-319 | URL de l'API en HTTP par défaut | Haute |
| RZ-05 | `backend/.../service/UserMediaStorageService.java:55-66,73-81` | A04 - Insecure Design / A05 - Security Misconfiguration | CWE-434 | Un fichier est accepté comme PDF si son type déclaré **ou** son extension vaut PDF, sans vérifier sa signature réelle | Haute |
| RZ-06 | `backend/.../security/SecurityConfig.java:51` | A05 - Security Misconfiguration | CWE-200 | Swagger/OpenAPI est publiquement accessible sans condition d'environnement | Moyenne |
| RZ-07 | `backend/.../controller/AuthController.java:97-180` | A07 - Identification and Authentication Failures | CWE-307 | Aucun rate limiting sur signup, login ou refresh | Haute |

## Détails des vulnérabilités

### RZ-01 - Fonctions KPI insuffisamment autorisées

`KPIController` expose les statistiques, l'export de tous les événements au format CSV et une fonction destructive de remise à zéro. Aucune vérification de rôle n'est appliquée dans le contrôleur. La configuration globale termine par `anyRequest().authenticated()`, donc un compte ordinaire suffit.

Impact : fuite de données d'usage, exposition du fonctionnement du matching et suppression des événements nécessaires à l'audit. La méthode `resetEvents` est décrite comme réservée au développement mais n'est pas protégée par un profil Spring.

Remédiation prévue : exiger `ADMIN` dans `SecurityConfig` ou avec `@PreAuthorize("hasRole('ADMIN')")`, désactiver le reset hors profil `dev` et tester les réponses 403 pour tous les autres rôles.

### RZ-02 - Suppression massive autorisée à tout utilisateur en développement

Les routes `DELETE /api/auth/users` et `DELETE /api/auth/users/by-email/{email}` sont limitées au profil `dev`, mais `SecurityConfig` exige uniquement une authentification. N'importe quel compte valide dans cet environnement peut donc supprimer toutes les données utilisateur ou cibler une adresse email.

Impact : perte totale ou ciblée de comptes et de profils, déni de service et destruction de données de test pouvant contenir des informations personnelles.

Remédiation prévue : retirer ces routes du contrôleur applicatif ou les réserver strictement au rôle `ADMIN`, avec double protection par profil et autorisation. Leur usage devrait idéalement être remplacé par des scripts locaux de réinitialisation.

### RZ-03 - Refresh tokens stockés en clair

L'entité `RefreshToken` contient la valeur JWT complète et le service recherche directement cette valeur. Une lecture de la base permet donc de réutiliser immédiatement les jetons actifs jusqu'à leur expiration.

Impact : prise de contrôle durable des sessions après compromission partielle de la base de données.

Remédiation prévue : générer un token opaque aléatoire, ne stocker que son empreinte SHA-256 et comparer les empreintes. À défaut, stocker uniquement une empreinte du JWT et conserver la rotation/révocation existante.

### RZ-04 - Communications mobiles non chiffrées par défaut

Le client utilise `http://localhost:8080` ou `http://10.0.2.2:8080`. Cette configuration est compréhensible pour un émulateur local mais aucune configuration de production n'impose HTTPS.

Impact : sur un réseau non fiable, les identifiants, JWT, messages, profils et fichiers peuvent être interceptés ou modifiés.

Remédiation prévue : fournir l'URL au build avec `--dart-define`, refuser toute URL non HTTPS en mode release et limiter l'autorisation Android du trafic clair au manifeste de debug.

### RZ-05 - Validation insuffisante du contenu des fichiers

Pour les justificatifs et brochures, la condition rejette seulement lorsque le MIME déclaré n'est pas PDF **et** que l'extension n'est pas `pdf`. Un attaquant peut donc envoyer n'importe quel contenu sous le nom `document.pdf`, ou déclarer `Content-Type: application/pdf`. Aucun magic number `%PDF-` ni parseur PDF n'est consulté.

Impact : stockage de contenu arbitraire, diffusion de contenu actif ou malveillant et risque pour les utilisateurs ou outils qui ouvrent ensuite les justificatifs.

Remédiation prévue : exiger simultanément l'extension autorisée et un type détecté côté serveur, vérifier la signature et parser le document, servir les justificatifs en téléchargement avec un type fixe, et envisager une analyse antivirus.

### RZ-06 - Documentation d'API exposée publiquement

Les chemins Swagger et OpenAPI sont déclarés `permitAll` sans condition. Ils fournissent à un attaquant un inventaire précis des endpoints, structures et opérations sensibles.

Impact : reconnaissance accélérée et augmentation de la surface d'information exposée. Le niveau est moyen car la documentation ne constitue pas seule une compromission.

Remédiation prévue : désactiver Springdoc par défaut en production, ou restreindre la documentation à un rôle administrateur et à un réseau interne.

### RZ-07 - Absence de limitation des tentatives d'authentification

Les endpoints publics signup, login et refresh n'appliquent aucun quota par IP, compte ou fenêtre temporelle. Aucun composant Bucket4j, Resilience4j ou filtre équivalent n'est présent.

Impact : brute force, credential stuffing, création automatisée de comptes et consommation excessive de BCrypt/CPU.

Remédiation prévue : ajouter une limitation distribuée adaptée au contexte de déploiement, ralentir progressivement les échecs, journaliser sans exposer les mots de passe et surveiller les pics d'authentification.

## Inventaire des entrées utilisateur

| Endpoint ou source | Entrées | Validation observée | Risque restant |
|---|---|---|---|
| `POST /api/auth/signup` | email, mot de passe, rôle, identité et profil dynamique | Champs obligatoires et rôle analysé manuellement | Pas de limite de longueur complète, pas de rate limiting |
| `POST /api/auth/login` | email et mot de passe | Présence vérifiée, message d'erreur générique, BCrypt | Brute force et credential stuffing |
| `POST /api/auth/refresh` | refresh token | Signature, expiration, type, présence en BDD et rotation | Token réutilisable si la BDD est lue |
| `PUT /api/users/me` | identité et profil | Contrôles métier manuels | Validation à vérifier champ par champ |
| `PUT /api/users/me/pack` | UUID du pack | Résolution côté serveur | Manipulation du niveau de service à analyser |
| `/api/schools` | paramètres URL et fiche école | Rôle et propriétaire pour les écritures | Longueurs, URLs et contenu libre |
| `/api/companies` | paramètres URL et fiche entreprise | Rôle et propriétaire pour les écritures | Longueurs, URLs et contenu libre |
| `/api/offers` | identifiant, type, description, média | Rôle et propriété sur les écritures | Validation du texte et du vrai type de fichier |
| `/api/messages` | destinataire, contenu, pagination et identifiants | Authentification et contrôles de propriété observés | Taille du message et abus volumétrique |
| `/api/match` | actions de swipe, identifiants, filtres et pagination | Utilisateur issu du `Principal` | Valeurs, volumes et extraction de profils |
| `/api/chat` | message et historique | Authentification et règles de pack | Injection de contenu et consommation de ressources |
| `/api/users/me/media` | photos, PDF, catégorie et identifiant | Taille, MIME déclaré, extension et propriétaire | Contenu réel non détecté |
| `/api/kpi` | aucun corps, mais opérations de lecture/reset | Authentification uniquement | Rôle administrateur absent |
| Application Flutter | URL du backend et médias distants | Construction d'URI | HTTP autorisé par défaut et URL distante à contrôler |

## Gestion des secrets

Points positifs : le mot de passe PostgreSQL et le secret JWT sont lus depuis des variables d'environnement ; `.env` est ignoré par Git ; le mobile utilise `flutter_secure_storage` pour les jetons.

Points à améliorer : stocker uniquement l'empreinte des refresh tokens, utiliser un gestionnaire de secrets en production, faire tourner toute valeur historiquement exposée, imposer HTTPS et bloquer la pipeline avec GitLeaks.

## Comparaison à préparer

Après exécution des scanners, ce document sera comparé aux résultats Semgrep, Snyk, Trivy et GitLeaks. Une absence d'alerte automatique pour RZ-01 ou RZ-02 illustrera notamment la difficulté des outils à comprendre l'autorisation métier.

