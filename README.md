# Rezo - Projet intégratif DevSecOps

Ce dépôt regroupe l'application mobile Flutter **Rezo** et son API Spring Boot afin de réaliser l'audit demandé dans le cadre du module Sécurité Logicielle & DevSecOps (2INF2311).

## Composants

- `rezo/` : application mobile Flutter (client non fiable du point de vue du backend).
- `backend/` : API REST Spring Boot, authentification JWT, PostgreSQL et stockage de médias.
- `.semgrep/` : règles SAST personnalisées du projet.
- `.github/workflows/` : pipeline DevSecOps GitHub Actions.
- `screenshots/` : preuves d'exécution et alertes corrigées.
- `docs/` : architecture, inventaires et éléments du threat modeling.
- `RAPPORT_FINAL.md` : rapport final de l'examen.

## Exécution locale

1. Copier `.env.example` vers `backend/.env` et renseigner uniquement des valeurs locales.
2. Démarrer PostgreSQL et créer la base indiquée par `REZO_DB_NAME`.
3. Démarrer l'API depuis `backend/` avec `mvnw.cmd spring-boot:run` sous Windows.
4. Démarrer l'application depuis `rezo/` avec `flutter run`.

Le fichier `.env` ne doit jamais être commité. Une valeur exposée dans Git doit être considérée comme compromise et remplacée.

## Contrôles DevSecOps prévus

- Threat modeling : OWASP Threat Dragon et STRIDE.
- SAST : Semgrep avec règles custom et règles OWASP.
- Détection de secrets : GitLeaks sur l'historique Git complet.
- SCA : Snyk et Trivy filesystem.
- Conteneur : build multi-stage du backend et scan Trivy de l'image.
- Centralisation : résultats SARIF dans GitHub Code Scanning.

