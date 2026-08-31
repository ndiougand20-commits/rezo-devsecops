# Règles Semgrep personnalisées de Rezo

Le fichier `rules.yaml` contient sept règles adaptées au code Java/Spring et Dart/Flutter du projet.

| Règle | Pattern dangereux | Justification | Correctif attendu |
|---|---|---|---|
| `rezo-java-sql-injection-concatenation` | Concaténation dans `createNativeQuery`, `createQuery` ou `JdbcTemplate` | Une future requête dynamique pourrait transformer une entrée en code SQL | Requête paramétrée et valeurs séparées |
| `rezo-java-command-injection` | Valeur dynamique passée à `Runtime.exec` ou `ProcessBuilder` | Les imports, conversions et traitements de médias ne doivent pas lancer une commande contrôlée par le client | API dédiée, liste blanche et arguments séparés |
| `rezo-java-hardcoded-secret` | Variable au nom sensible affectée à une chaîne longue | Empêche l'ajout de mots de passe, clés ou tokens au backend | Variable d'environnement ou gestionnaire de secrets |
| `rezo-dart-insecure-http-backend` | URL backend commençant par `http://` | Le client transporte identifiants, JWT, messages et fichiers | HTTPS obligatoire en release |
| `rezo-java-plaintext-refresh-token-persistence` | Appel `setToken` sur un objet refresh token | Le projet conserve actuellement un refresh token réutilisable en BDD | Empreinte SHA-256 du token opaque |
| `rezo-spring-public-openapi` | Swagger/OpenAPI associé à `permitAll` | La documentation publique facilite la reconnaissance de l'API | Désactivation en production ou accès administrateur |
| `rezo-java-upload-type-or-extension` | Rejet seulement si MIME et extension sont tous deux invalides | Un faux PDF est accepté si un seul attribut contrôlé par le client paraît valide | Extension autorisée et type réel détecté |

Les deux premières règles satisfont l'exigence relative aux injections. La règle de commande emploie `pattern-not` afin d'écarter les commandes littérales. La règle de secrets et plusieurs règles spécifiques utilisent `metavariable-regex`.

## Exécution locale

Depuis la racine du dépôt :

```shell
semgrep --config .semgrep/rules.yaml --error .
```

La pipeline combinera ce fichier aux règles maintenues par Semgrep pour l'OWASP Top 10. Les résultats custom seront exportés au format SARIF.

## Résultat de référence avant correction

Validation réalisée avec Semgrep OSS 1.174.0 dans le conteneur officiel Linux : 7 règles valides, 115 fichiers source analysés et aucune erreur d'analyse.

| Règle | Occurrences | Résultat |
|---|---:|---|
| `rezo-java-sql-injection-concatenation` | 0 | Aucun pattern de concaténation SQL ciblé trouvé |
| `rezo-java-command-injection` | 0 | Aucun appel dynamique ciblé à une commande système |
| `rezo-java-hardcoded-secret` | 0 | Aucun secret Java correspondant au pattern |
| `rezo-dart-insecure-http-backend` | 3 | `services.dart` lignes 135, 139 et 142 |
| `rezo-java-plaintext-refresh-token-persistence` | 1 | `RefreshTokenService.java` ligne 36 |
| `rezo-spring-public-openapi` | 1 | `SecurityConfig.java` lignes 47 à 51 |
| `rezo-java-upload-type-or-extension` | 2 | `UserMediaStorageService.java` lignes 59 et 77 |

Le total initial est de 7 occurrences. Les règles sans résultat restent nécessaires comme garde-fous contre de futures régressions et satisfont l'exigence de détection des injections.
