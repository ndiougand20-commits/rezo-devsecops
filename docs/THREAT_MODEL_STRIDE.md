# Modèle de menaces STRIDE — Rezo

Le modèle exportable se trouve dans `threat-model.json` et sa représentation issue de Threat Dragon dans `screenshots/dfd-threat-dragon.png`. Il contient deux frontières de confiance : le terminal mobile non fiable et l'infrastructure serveur contrôlée.

| Priorité | Composant ou flux | STRIDE | Menace | Sévérité | Mitigation |
|---:|---|---|---|---|---|
| 1 | Mobile / API | Spoofing | Vol d'un JWT ou refresh token et usurpation du compte | Haute | HTTPS, secure storage, rotation, révocation et empreinte des refresh tokens |
| 2 | Application mobile | Tampering | Client modifié forgeant rôles et requêtes | Haute | Validation et autorisation exclusivement côté API |
| 3 | API | Elevation of privilege | Appel des KPI ou suppressions par un rôle standard | Haute | `hasRole("ADMIN")`, `@PreAuthorize` et tests négatifs |
| 4 | API d'authentification | Denial of service | Rafale de login/signup/refresh | Moyenne | Rate limiting, quotas, backoff et supervision |
| 5 | Actions administratives | Repudiation | Suppression ou reset sans preuve de l'auteur | Moyenne | Journal d'audit immuable et corrélé |
| 6 | PostgreSQL | Information disclosure | Exposition de profils, messages et données scolaires | Haute | Moindre privilège, chiffrement, contrôle objet et sauvegardes protégées |
| 7 | PostgreSQL | Tampering | Altération des rôles, packs, offres ou matches | Haute | Contraintes, transactions, contrôles de rôle et audit |
| 8 | Upload vers stockage | Tampering | Faux PDF ou média actif distribué comme légitime | Haute | MIME + extension + signature magique, taille, nom aléatoire, stockage non exécutable |

Les huit menaces couvrent six catégories : Spoofing, Tampering, Repudiation, Information Disclosure, Denial of Service et Elevation of Privilege.

## Trois menaces prioritaires

1. **Usurpation de session.** Rezo concentre identité, orientation, recherche d'emploi et conversations. Le vol d'une session permet d'exfiltrer ces données et d'agir au nom de la victime. Le refresh token est désormais stocké sous forme d'empreinte SHA-256.
2. **Élévation de privilèges.** Les fonctions KPI, export, reset et suppression ont un impact transversal. Leur exploitation permettrait la destruction ou l'extraction massive de données. Elles sont désormais limitées au rôle `ADMIN`.
3. **Divulgation des données PostgreSQL.** Une compromission de la base affecterait simultanément tous les profils et messages. Le risque résiduel exige du chiffrement au repos, un compte SQL à privilèges minimaux et des sauvegardes chiffrées.
