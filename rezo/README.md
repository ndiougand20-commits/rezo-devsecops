# REZO Frontend Mobile

---

## Description

REZO Frontend est l’application mobile Flutter destinée aux étudiants, lycéens, chercheurs d’emploi, écoles et entreprises, pour l’accès à la plateforme de matching, messagerie, orientation et gestion de packs.

---

## Stack Technique

- **Langage** : Dart
- **Framework** : Flutter (3.x recommandé)
- **State management** : Provider / Riverpod / Bloc (à préciser selon ton choix)
- **API** : HTTP package (connexion à l’API Spring Boot)
- **Gestion des assets** : `/assets` (images, polices...)

---

## Structure du projet

```plaintext
rezo-frontend/
├── lib/
│   ├── main.dart          # Point d’entrée
│   ├── screens/           # Pages (accueil, profil, matching, chat, etc.)
│   ├── widgets/           # Composants custom réutilisables
│   ├── models/            # DTOs/données
│   ├── services/          # Requêtes API, gestion session, chat IA, etc.
│   └── utils/             # Constantes, helpers, theme
├── assets/
│   ├── images/
│   └── fonts/
├── docs/                  # Guides utilisateur, documentations
├── pubspec.yaml           # Dépendances Flutter
├── README.md
```

---

## Installation rapide

1. **Pré-requis :**
   - [Flutter installé](https://docs.flutter.dev/get-started/install) (3.x+ recommandé)
   - Un simulateur Android/iOS ou un appareil physique

2. **Configurer le projet** :
    - Récupérer les dépendances :
      ```bash
      flutter pub get
      ```

3. **Lancer l’application :**
    - Sur simulateur :
      ```bash
      flutter run
      ```
    - Pour build APK (Android) :
      ```bash
      flutter build apk
      ```
    - Pour iOS, nécessaire d’avoir un Mac et Xcode.

4. **Connexion à l’API**
    - Vérifier que l’API backend (Spring Boot) est bien accessible
    - Modifier l’URL base API dans `/lib/services/api_service.dart` si besoin
    
---

## Fonctionnalités prévues (MVP)

- Inscription/connexion multi-profils (étudiant, lycée, école, entreprise)
- Onboarding, édition de profil complet
- Matching (swipe, suggestions personnalisées)
- Gestion de packs, achat/changement
- Messagerie interne entre utilisateurs/entreprises/écoles
- Chat IA support intégré (conseils, packs, orientation)
- Notifications (push/snackbar locales)
- UX fluide mobile-first

---

## Liens utiles

- [User stories & profils](/docs/USER_STORIES)
- [Guide Flutter officiel](https://docs.flutter.dev/)

---

## Roadmap MVP

1. Setup navigation de base et design system
2. Écrans d’authentification/onboarding
3. Edition profil/gestion formulaire
4. Intégration appel API Auth, CRUD utilisateurs, etc.
5. Écran de matching (swipe)
6. Intégration messagerie et chat IA
7. Gestion des packs et UX feedback
8. Tests utilisateurs & QA

---

## Contribution

- Toute page/feature dans un nouveau widget/screen (éviter code spaghetti dans `main.dart`)
- Privilégier state management choisi pour la cohérence (Provider/Bloc/etc.)
- Respecter la convention des dossiers
- Docs dans `/docs` dès modification majeure

---

## Contact

Pour toute question, suggestion ou bug :
- Ndiouga NDIAYE : ndiougand20@gmail.com

