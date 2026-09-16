# `packages/secrets` — rapport final commun avant release

**15 septembre 2026 — Claude (B) et Codex (A), convergé dans `ECHANGE.md`.** Le détail, les preuves et les journaux sont dans le rapport de Codex, `/tmp/secrets-release-audit-20260915/RAPPORT_RELEASE.md` ; ce document est la couche de décision. Tout ce qui suit a été accepté par les deux agents ; les deux points où les positions ont d'abord divergé sont signalés.

## Verdict commun

**Le découpage du package est bon et se conserve. Le package et sa migration ne sont pas livrables aujourd'hui.** Ce qui manque n'est pas de la structure : ce sont des contrats non tranchés (passphrase, cohorte Android), une capacité de signature sans fin de vie, deux affichages bruts, une course d'import, et des tests qui n'attestent pas ce que la documentation promet.

## État mesuré

| contrôle | résultat |
|---|---|
| `make analyze` projet entier | **vert** (292 → 0 sur la session) |
| `make format-check`, `make fix-check`, `make bull-ui-check` | **verts** |
| tests du package | **112/112** |
| `make unit-test` (avec `libsqlite3.so` lié — voir note) | **1951 réussis, 1 échec** : `transaction_error_surface_test` |
| migration | 22 fichiers `lib/`, 12 tests, 4 intégration ; zéro import de `src/seed/` ; **rien de commité** |

Note : le conteneur n'a pas le lien de développement `libsqlite3.so` ; sans lui, ~150 tests de migration échouent d'une façon qui ressemble à des défauts de code. Codex l'a contourné sous `/tmp` seulement ; Claude a installé `~/.local/lib/libsqlite3.so` et ajouté `LD_LIBRARY_PATH` à `~/.bashrc` (session du 15 septembre, ligne commentée, réversible).

## Ce qui est acquis (fait pendant l'audit, vérifié par les deux)

Propriété des buffers ; vérification d'identité à la matérialisation ; verrou sur la seule opération composée, refus non destructif des DEK abîmées, `bytesHex` et `v` validés ; classement des mauvais mots à leur origine ; sentinelle stockée jamais dans une failure ni un log ; `KeyKind` ; exceptions par module infra ; `guard` et la boucle de retry en `on Exception` ; `Secret.liquidXpub` avec les coin types historiques 1776/1 ; `MnemonicView` scellé, robuste au changement d'identité et aux réponses périmées ; `PsbtSigner` synchrone ; barrel à `show` explicites ; `package:secrets/testing.dart` pour les tests des consommateurs ; parseur BIP85 qui vérifie durcissement, application et index.

## Décisions prises par Nicolas (15 septembre 2026)

1. **Cohorte Android fss9 — retrait acté.** Le fallback `EncryptedSharedPreferences` n'est pas rétabli. R4 devient : écrire la décision, et garantir qu'un appareil resté sur l'ancienne génération voit « aucun secret trouvé, importez votre sauvegarde » — pas un crash. Test avec une fixture fss9 seule.
2. **Passphrase**, par opération, sans changer une dérivation existante :
   - **Sauvegardes — signaler (A).** Format inchangé. `backupVault` sur un secret à passphrase rend un résultat distinct ; `restoreVault` signale « restauré sans passphrase » ; l'app propose de la ressaisir et ré-importe (W, P). Aucun secret ajouté au vault.
   - **Liquid — signaler (A).** `liquidDescriptor` marque son résultat « dérivé des mots seuls » ; l'app l'affiche. Une racine lwk avec passphrase reste un suivi tracé, dépendant de l'amont.
   - **Swaps — `walletPassphrase` (B).** Les nouvelles clés de swap dérivent (W, P) ; les clés déjà stockées ne changent pas ; le signal (A) reste tant que ce n'est pas livré.
3. **`Failure.toString()` réduit au type.** `logMessage` se lit explicitement là où on le veut. Le seul test rouge passe au vert.
4. **Dérogation à la règle 6** pour `SecretRepository` : concret, la couture de test étant sous le repository (`FlutterSecureStoragePlatform.instance`). À consigner dans ARCHITECTURE.md § Monorepo et dans le README du package.
5. **Entrées déjà incohérentes — échec typé + réparation (A).** Nouvelle variante `SecretIdentityMismatchFailure` ; détection paresseuse à la première opération ; l'app propose de ré-importer la bonne mnemonic pour X, ou de re-classer les mots stockés sous leur vraie identité Y quand ils sont une mnemonic valide.
6. **Base/DEK illisibles — bloquer, alerter, reset explicite.** `DatabaseKeyCorruptFailure` remonte une erreur bloquante ; une API destructive nommée sans ambiguïté, `Secrets.resetDatabaseKey(package:, name:)`, n'est appelée que par un geste de développeur, jamais par une récupération automatique, après suppression de la base par son module.

## Travaux avant livraison — R1 à R9

| # | travail | critère d'acceptation |
|---|---|---|
| R1 | Passphrase : résultat distinct sur `backupVault` et `liquidDescriptor` pour un secret à passphrase ; `restoreVault` signale l'absence de passphrase ; `swapKey` passe `walletPassphrase` pour les nouvelles clés | tests avec/sans passphrase ; formats historiques ouverts ; aucun succès muet ; clés de swap existantes inchangées |
| R2 | Fin de vie des signers : rechargement par `signPsbt` async ; session courte à fermeture explicite pour le callback sync payjoin ; `dispose()` BDK et lwk ; erreurs traduites à chaque invocation | signature ECDSA vérifiée indépendamment ; fermeture même sur erreur ; refus après fermeture ; **une signature PSET valide** (non prouvée à ce jour) |
| R3 | Dernier affichage brut (`show_mnemonic_screen`) sur `MnemonicView` ; pour le credential de swap, un **affichage scellé approprié au credential dérivé** — `MnemonicView` prend un `Secret` et montre ses mots maîtres, il ne convient pas tel quel ; protection attendue avant rendu ; puis retrait de `revealWords` | tests de sémantique, changement d'identité, réponse périmée, échec de lecture ; aucun `List<String>` de mots ne traverse un bloc |
| R4 | Retrait fss9 acté ; chemin « aucun secret trouvé, importez votre sauvegarde » pour un appareil resté sur l'ancienne génération | fixture fss9 seule → ce chemin, sans crash ni suppression ; décision consignée |
| R5 | Import concurrent : sérialiser création et nettoyage, propriété explicite de la suppression ; le datasource partagé refuse aussi le namespace des DEK | deux imports concurrents dont un échoue préservent le seed du wallet réussi |
| R6 | Chemins BIP85 persistés validés — **fait** ; reste : résultat incomplet non présenté comme complet | fixtures HEX/BIP39 historiques ; lignes illisibles tracées vers l'appelant |
| R7 | Repository → `Result` (règle 11) ; `_parseAll` en `on Exception` ; `LiquidSigner` sans message étranger brut ; conversions `Err → StateError` retirées des consommateurs ; `Failure.toString()` réduit au type ; `SecretIdentityMismatchFailure` + usecase de réparation ; `Secrets.resetDatabaseKey` explicite | aucune `SecretFailure` construite dans `public/` ; erreurs de programmation non absorbées ; audit rouge réparé |
| R8 | Inventaire réel de la surface (sorties voulues **par conception** : `bip85Hex`, `bip85Mnemonic`, `swapKey`, `databaseKey` ; capacité : `psbtSigner` ; ciphertext + clé : `backupVault`) ; invariants qui suivent les exports transitifs et énumèrent chaque méthode ; README et dartdoc **courts, conceptuels** ; verrou dit « par isolate » ; limites mémoire dites | ajouter un export ou une méthode inconnue rougit la suite ; chaque affirmation du README a un test ou une mention « non testé » |
| R9 | Preuves durables : vecteurs de vault OLD/NEW dans `vault_test.dart` ; fixtures de signature BDK/LWK publiques en CI ; sondes de l'audit converties en régressions ; anti-écrasement à l'import sous le verrou | `make checks` vert sur un état identifié ; matrice appareil jointe |

## Ordre

1. Acter les six décisions — elles conditionnent R1, R4, R7.
2. Poser les régressions avant chaque correctif (R9, les sondes de l'audit inversées).
3. Corriger les comportements sensibles : R2, R3, R5, anti-écrasement.
4. Frontières et redaction : R7.
5. Inventaire et documentation sur l'état final : R8.
6. Valider le candidat : checks verts, tests natifs permanents, matrice appareil.

Premier commit : le package et l'adaptation de ses consommateurs ensemble, **si le diff le confirme** — le package est né non commité (ses durcissements et sa base sont dans les mêmes fichiers non suivis) et le hook refuse tout commit tant que l'app ne compile pas, ce qui lie les deux ; à vérifier sur le diff plutôt qu'à supposer. Ensuite, commits atomiques par lot, comme les règles l'exigent.

## Où les positions ont divergé, et comment

- **fss9** : Claude le voulait « bloquant en attente de décision », Codex « condition de livraison ». Clarifié : les deux — la décision change le périmètre, la preuve reste due.
- **Anti-écrasement** : Claude en faisait un « à faire », Codex un pré-release. Claude a rejoint Codex : petit correctif, classe de destruction silencieuse fermée.

## Limites de l'audit

Aucune signature PSET valide vérifiée ; aucun essai sur appareil Android/iOS ni d'upgrade réel ; aucune preuve de zéroïsation mémoire ; les contrôles natifs ont tourné sous Linux. Les tests financés (Alice, Bob) restent une couche distincte des fixtures publiques.
