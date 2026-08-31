# Analyse des vulnérabilités de composants

## Méthode

Les images ont été analysées avec Trivy en limitant le résultat aux niveaux `HIGH` et `CRITICAL` et aux vulnérabilités disposant d'un correctif (`--ignore-unfixed`). Les fichiers JSON bruts restent dans `reports/`, répertoire ignoré par Git.

## Comparaison avant/après

| Image | HIGH | CRITICAL | Total | CVE/GHSA uniques |
|---|---:|---:|---:|---:|
| Image initiale | 80 | 10 | 90 | 57 |
| Après Spring Boot 4.0.6 et Alpine 3.22 récent | 19 | 3 | 22 | 17 |
| Image finale après surcharges correctives | 0 | 0 | 0 | 0 |

Cette première remédiation réduit les occurrences bloquantes de 75,6 %. Le scan a notamment confirmé la disparition des alertes Spring Boot 4.0.3, Spring Security 7.0.3 et de nombreux paquets Alpine anciens.

## CVE résiduelles du scan intermédiaire

| Identifiant | Composant installé | Correctif indiqué par Trivy | Sévérité |
|---|---|---|---|
| CVE-2026-41293 | Tomcat Embed Core 11.0.21 | 11.0.22 | Critique |
| CVE-2026-43512 | Tomcat Embed Core 11.0.21 | 11.0.22 | Critique |
| CVE-2026-43515 | Tomcat Embed Core 11.0.21 | 11.0.22 | Critique |
| CVE-2026-42498, CVE-2026-43513, CVE-2026-41284 | Tomcat Embed Core 11.0.21 | 11.0.22 | Haute |
| CVE-2026-41842, CVE-2026-41845 | Spring Web MVC 7.0.7 | 7.0.8 | Haute |
| CVE-2026-41850 | Spring Expression 7.0.7 | 7.0.8 | Haute |
| CVE-2026-41716 | Spring Data Commons 4.0.5 | 4.0.6 | Haute |
| CVE-2026-54291 | PostgreSQL JDBC 42.7.10 | 42.7.12 | Haute |
| CVE-2026-54512, CVE-2026-54513 | Jackson Databind 2.21.2 | 2.21.4 | Haute |
| GHSA-r7wm-3cxj-wff9 | Jackson Core 2.21.2 | 2.21.4 | Haute |
| CVE-2026-14456 | OpenSSL/`libcrypto3` 3.5.7-r0 | 3.5.8-r0 | Haute |

Les versions correctives ci-dessus sont surchargées dans le `pom.xml`; l'image finale exécute également la mise à niveau des paquets Alpine pendant sa construction. Le scan final ne produit plus aucune vulnérabilité HIGH ou CRITICAL corrigible et satisfait donc la quality gate Trivy image.

## Interprétation

Une CVE désigne ici une vulnérabilité concrète d'une version publiée d'une dépendance. Une CWE décrit au contraire une famille de défauts : par exemple, la validation insuffisante des PDF relève de CWE-434 sans constituer à elle seule une CVE du projet Rezo.
