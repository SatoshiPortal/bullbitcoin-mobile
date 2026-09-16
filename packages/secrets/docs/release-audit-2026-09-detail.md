# Audit de livraison — `packages/secrets`

**15 septembre 2026 — audit Codex, plan de travaux confronté et accepté avec Claude dans [ECHANGE.md](/tmp/secrets-architecture-review/ECHANGE.md).** L’accord porte sur les travaux avant livraison et les décisions restantes ; il ne constitue pas une validation de release.

## Verdict

**Je conserve le découpage du package, mais je ne recommande pas encore sa livraison avec la migration applicative.** Les corrections de propriété des buffers, d’identité à la lecture et de création des clés de base ont une valeur réelle. Les problèmes restants concernent surtout le contrat des sauvegardes avec passphrase, la durée de vie des signers, les derniers affichages de secrets, la compatibilité Android et certaines opérations concurrentes.

L’analyse statique est verte et les **112 tests du package passent après les dernières corrections**. Cela ne suffit pas à valider la release : la suite applicative conserve **un échec de redaction**, le formatage a été corrigé pendant la revue, et plusieurs comportements sensibles ne sont pas encore gardés par des tests permanents.

## Périmètre et méthode

Revue de tous les fichiers Dart de `packages/secrets/lib` et `test`, des barrels, modèles persistés, adaptateurs cryptographiques, options de keystore, documentation et principales intégrations : import/suppression, métadonnées de wallets, BIP85, Payjoin, RecoverBull et affichage des mnemonics. Les règles du dépôt, `ARCHITECTURE.md` et `FEATURES.md` font partie du contrat évalué.

État de travail local, **HEAD `7ca783e1a`**, avec une migration largement non commitée. Une copie initiale de 50 fichiers et leurs empreintes est conservée dans [snapshot](/tmp/secrets-release-audit-20260915/snapshot) et [manifest-start.json](/tmp/secrets-release-audit-20260915/manifest-start.json). L’état final de 58 fichiers, intégrations critiques incluses, est conservé dans [snapshot-final](/tmp/secrets-release-audit-20260915/snapshot-final) et [manifest-final.json](/tmp/secrets-release-audit-20260915/manifest-final.json). Les numéros de ligne ci-dessous désignent l’état audité et peuvent évoluer avec les corrections.

Je n’ai modifié aucun fichier source du dépôt, créé aucun commit ni diffusé de transaction. Mes sondes utilisent des mnemonics publiques, des PSBT synthétiques et un stockage factice. Les signatures BDK et les dérivations LWK/Boltz utilisent les bibliothèques natives ; les tests du keystore ne remplacent pas des essais Android/iOS.

Claude a corrigé le widget, le retry et le parsing BIP85, puis appliqué le formatage pendant l’échange. Ces changements sont distingués des défauts encore ouverts, et ont été vérifiés indépendamment ci-dessous.

## 1. Ce qui est acquis et à conserver

| Élément | Évaluation |
|---|---|
| `Secrets` / `Secret` / `SecretInfo` | Séparation utile entre cycle de vie, opérations et description. Le handle ne contient pas de seed en champ. |
| Buffers d’entrée | Les modèles copient les données avant l’attente asynchrone ; `DatabaseKey` protège son buffer. L’ancienne substitution par mutation de la liste n’est plus un défaut ouvert. |
| Identité à la matérialisation | `SecretRepository.materialize` compare désormais le fingerprint dérivé à celui de l’entrée. Une entrée déplacée est refusée. Cela ne résout pas une collision entre deux fingerprints identiques. |
| Clés de base — DEK | La création composée est verrouillée entre instances du même isolate. Une entrée vide, mal formée ou de version invalide est refusée sans écrasement ; les 32 octets sont validés. |
| Import / vault invalides | Le mauvais nombre de mots est classé à l’origine ; un vault à checksum invalide et une DEK avec `v: 1.0` sont refusés. Les sondes P1/P5 confirment aussi l’absence d’écriture. |
| Dérivations historiques | Les goldens de stockage et vecteurs existants sont utiles. N1 confirme le xpub Liquid avec les coin types historiques 1776/1, pour les types de script supportés, avec et sans passphrase. |
| Signature Bitcoin | S1 vérifie indépendamment une signature ECDSA BIP84 aux indices 0 et 100, avec passphrase. Le contrôle porte sur la signature et son préimage BIP143. |
| BIP85 / swaps | L’export de secrets enfants est une fonctionnalité légitime. Il faut l’inventorier comme tel ; leur caractère dérivé ne les rend pas publics au sens cryptographique. |

### Corrections faites pendant cet audit

- **`MnemonicView`** : l’état initial gardait les mots de A après réception du handle B, reproduit par P6. Un premier correctif provoquait une assertion Flutter car son callback `setState` retournait un `Future`. Le dernier correctif renouvelle le Future et le `FutureBuilder` par identité et attend sa complétion. **W1 passe** : aucun ancien mot pendant l’attente, réponse périmée ignorée, pas de nouvelle lecture pour le même id, mots exclus de la sémantique. Ce test vit encore sous `/tmp` et doit rejoindre le dépôt.
- **Retry du keystore** : P2 montrait qu’un `StateError` était absorbé puis suivi d’un succès. `_readGuarded` attrape maintenant uniquement les `Exception`. **P2 final passe** : le `StateError` se propage dès le premier appel. D’autres catches larges subsistent, notamment dans le parsing de liste.

- **Chemins BIP85** : P8 a motivé un correctif du durcissement, du numéro d’application et de la concordance d’index, avec quatre tests permanents ajoutés par Claude. Le contrat des résultats partiels reste à décider ; R6 distingue ces deux sujets.
- **Formatage** : les 25 fichiers signalés par le premier contrôle sont corrigés ; le contrôle final est vert, ainsi que la vérification séparée des 46 fichiers du package incluant les non-suivis.

Le comportement de renouvellement d’état et de conservation des données d’un FutureBuilder a été recoupé avec les sources Flutter le 15 septembre 2026 : [didUpdateWidget](https://api.flutter.dev/flutter/widgets/State/didUpdateWidget.html), [FutureBuilder](https://api.flutter.dev/flutter/widgets/FutureBuilder-class.html).

## 2. Travaux nécessaires avant livraison

### R1 — Rendre explicite ce que sauvegarde et restaure un secret avec passphrase

**Constat exécuté :** P3 importe des mots avec une passphrase, crée un vault puis le restaure. Les deux opérations réussissent, mais le secret restauré a **une autre identité et aucune passphrase**. La clé de chiffrement vient du seed avec passphrase ; le contenu sauvegardé contient uniquement les mots. Formulation exacte : **le vault chiffre avec cette identité, puis restaure sans sa passphrase**.

N2/N3 confirment également que les descripteurs Liquid et credentials de swap sont identiques pour les mêmes mots avec deux passphrases différentes. En revanche, le xpub de métadonnées Liquid tient compte de la passphrase : le handle n’a donc pas une sémantique uniforme pour toutes ces opérations.

Références : [backupVault](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/public/secret.dart:246), [LiquidDeriver](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/crypto/derivers/liquid_deriver.dart:24), [BoltzDeriver](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/crypto/derivers/boltz_deriver.dart:25), [restauration applicative](/home/nicolas/Cage/repos/BULL/lib/core/recoverbull/domain/usecases/restore_vault_usecase.dart:25).

**Travail :** choisir séparément le contrat des sauvegardes, de Liquid et des swaps. Signaler au runtime la portée historique fondée sur les mots seuls ; pour le backup, rendre visible qu’une passphrase externe reste indispensable à la restauration de l’identité complète, ou proposer un format qui la prend en charge selon une décision explicite. Préserver l’accès aux wallets et swaps existants.

**Acceptation :** tests avec/sans passphrase, ouverture des formats historiques, restauration de l’identité attendue ou résultat explicitement partiel. Aucun changement silencieux de dérivation ; aucun succès présenté comme une restauration complète lorsqu’elle ne l’est pas. Cette différence découle aussi de [BIP39](https://github.com/bitcoin/bips/blob/master/bip-0039.mediawiki), vérifié le 15 septembre 2026.

### R2 — Donner un propriétaire et une fin de vie aux capacités de signature

**Constat exécuté :** S2 crée un `psbtSigner`, supprime le secret du keystore, puis obtient encore une **signature ECDSA valide sans aucune relecture**. Une PSBT malformée invoquée sur ce callback lève directement `Base64EncodingPsbtParseException` hors de la frontière `Result`.

Références : [Secret.psbtSigner](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/public/secret.dart:227), [BitcoinSigner](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart:28), [LiquidSigner](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/crypto/signers/liquid_signer.dart:52).

**Travail :** conserver le rechargement à chaque `signPsbt` asynchrone ; pour le callback synchrone imposé par Payjoin, définir une session courte avec propriétaire, fermeture et politique d’invalidation. Préciser ce que font annulation, suppression, verrouillage applicatif et fin du protocole. Traduire les erreurs à chaque invocation. Libérer explicitement les ressources natives détenues, y compris sur échec.

Les bindings épinglés proposent `bdk.Wallet.dispose()` et, pour LWK, `Wallet implements RustOpaqueInterface` dont `dispose()` libère l’Arc natif. Leur libération ne prouve pas la zéroïsation de toutes les copies en mémoire.

**Acceptation :** signatures Bitcoin valides avec vérification indépendante ; fermeture même sur erreur ; refus d’utilisation après fermeture ; politique de suppression/verrouillage testée. Ajouter une **signature PSET valide LWK** : N4 n’a testé que le refus d’un PSET invalide et le nettoyage réussi du répertoire temporaire.

### R3 — Finir la migration des affichages et vérifier la protection avant le rendu

Le widget du package est corrigé, mais le parcours de test du backup conserve sa propre sortie brute : [GetMnemonicFromFingerprintUsecase](/home/nicolas/Cage/repos/BULL/lib/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart:17) → [méthode du bloc](/home/nicolas/Cage/repos/BULL/lib/features/test_wallet_backup/presentation/bloc/test_wallet_backup_bloc.dart:47) → [ShowMnemonicScreen](/home/nicolas/Cage/repos/BULL/lib/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart:100). Mots et passphrase traversent encore ces frontières.

Le `FutureBuilder` de protection de cet écran ignore l’état de son Future ([ligne 36](/home/nicolas/Cage/repos/BULL/lib/features/test_wallet_backup/ui/screens/show_mnemonic_screen.dart:36)) et construit l’affichage immédiatement. Aucun `ExcludeSemantics` n’entoure ses mots. L’affichage du credential de swap dans l’écran « toutes les seeds » mérite le même contrôle.

**Travail :** faire afficher le secret par le composant interne au package, utiliser `verifyWords` pour les comparaisons, et retirer la sortie brute destinée à l’affichage lorsque les consommateurs sont migrés. Attendre l’activation effective de la protection ; traiter son échec sans montrer les mots. Inclure les secrets dérivés affichés dans cette politique.

**Acceptation :** tests de sémantique, protection en attente/en erreur, changement de wallet, suppression/réordonnancement, réponse asynchrone périmée et échec de lecture. Le test doit examiner l’API et l’arbre de sémantique ; prétendre que `find.text` ne peut pas inspecter un widget scellé serait faux.

### R4 — Résoudre la compatibilité Android avant de retirer l’ancien chemin de lecture

[StorageLocator](/home/nicolas/Cage/repos/BULL/lib/core/storage/storage_locator.dart:10) constate le retrait du fallback fss9/EncryptedSharedPreferences utilisé par une cohorte Android historique. Le package choisit `migrateOnAlgorithmChange: false`, sans activer l’ancien mode ESP ([datasource](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/data/fss_datasource.dart:130)).

**Preuve de code :** dans le plugin installé 10.3.3, [FlutterSecureStorage.java:170–195](/home/nicolas/.pub-cache/hosted/pub.dev/flutter_secure_storage-10.3.3/android/src/main/java/com/it_nomads/fluttersecurestorage/FlutterSecureStorage.java:170), la présence de données ESP non migrées avec ces options produit `callback.onError`, puis un retour. Le plugin ne les lit donc pas automatiquement dans ce cas. La documentation confirme qu’il existe plusieurs modes et chemins de migration : [flutter_secure_storage 10.3.3](https://pub.dev/packages/flutter_secure_storage/versions/10.3.3), vérifié le 15 septembre 2026.

**Travail :** soit préserver et tester l’upgrade de cette cohorte, soit acter explicitement son retrait du périmètre supporté avec un parcours de récupération défini. L’avertissement montré par une ancienne version ne prouve pas que toutes les installations ont migré. Ne pas changer les options de migration sans essais de compatibilité et d’interruption.

**Acceptation :** installation de la version historique sur appareil/émulateur de test, écriture d’une fixture publique, upgrade vers le candidat, lecture et dérivation identiques ; essais de redémarrage et d’échec, aucune suppression automatique. Pour iOS, couvrir lecture avant/après premier déverrouillage et retour applicatif approprié. **Ces essais n’ont pas été exécutés pendant cet audit.**

### R5 — Protéger toute l’orchestration d’import concurrent, pas seulement une écriture

**Constat exécuté P7 :** deux imports voient une absence, puis stockent les mêmes mots. Une création de wallet réussit ; l’autre échoue et son nettoyage supprime le seed partagé. Résultat : **un appel retourne un wallet avec succès alors que son seed n’est plus stocké**.

Référence : [ImportWalletUsecase](/home/nicolas/Cage/repos/BULL/lib/features/import_mnemonic/domain/import_wallet_usecase.dart:63). La sonde emploie la vraie façade et un faux plugin ; la création du wallet est simulée pour imposer le succès et l’échec. Le même schéma existait à HEAD : **défaut préexistant conservé par la migration**, pas une nouvelle régression attribuée à l’extraction. La sonde ne démontre pas qu’un double clic particulier déclenche ces deux appels dans l’UI.

**Travail :** sérialiser la décision de création et son nettoyage au niveau de l’orchestration applicative, et définir qui possède le droit de supprimer une entrée devenue partagée. Inclure les autres créations/suppressions susceptibles d’interagir. Un simple booléen issu d’une lecture antérieure n’établit pas cette propriété.

**Acceptation :** deux appels concurrents dont un échoue préservent le seed du wallet réussi ; une entrée préexistante survit ; un véritable orphelin est traité selon une politique explicite. Un verrou autour du seul `storeSecret` ne remplit pas ce critère.

### R6 — Finaliser la validation BIP85 et décider du signal de résultat partiel

**Constat exécuté P8 :** `128169'/32'/0'`, `128169/32/0` et `39'/32'/0'` étiqueté HEX produisent trois lignes de même valeur. Le parser initial enlevait les apostrophes et ignorait le numéro d’application du chemin ([usecase](/home/nicolas/Cage/repos/BULL/lib/core/bip85/domain/fetch_all_bip85_derivations_with_entropy_usecase.dart:85)). **Ce défaut de réinterprétation est corrigé pendant l’audit** : le chemin doit être durci, son application doit correspondre au tag et son index à la ligne. Quatre tests permanents ont été ajoutés dans [derive_next_bip85_usecase_test.dart](/home/nicolas/Cage/repos/BULL/test/core_test/bip85/derive_next_bip85_usecase_test.dart:263). Les formes refusées restent omises du résultat après un avertissement dans les logs.

**Travail restant :** compléter les fixtures historiques et la validation des bornes/paramètres ; décider ce que voit le consommateur lorsqu’une ligne est ignorée. Nous ne prescrivons pas encore la forme d’un nouveau DTO. Le contrat de liste partielle est une décision d’API à prendre explicitement, distincte du défaut de réinterprétation désormais corrigé.

**Acceptation :** fixtures historiques HEX/BIP39 avec valeurs attendues, réseau actif et fingerprint du root ; refus des chemins contradictoires ou non durcis ; résultat traçable pour chaque ligne. Le lot « une lecture pour N dérivations » est une optimisation indépendante de cette correction. Référence : [BIP85](https://github.com/bitcoin/bips/blob/master/bip-0085.mediawiki), vérifié le 15 septembre 2026.

### R7 — Terminer les frontières d’erreurs et la redaction

Le repository concret renvoie encore des valeurs ou lève des exceptions ; `guard` dans `public/` fait l’essentiel du mapping. La règle 11 demande une frontière de repository retournant des `Result`, puis une composition des résultats. Claude rapporte une instruction explicite de Nicolas en faveur de cette correction.

**Travail :** mapper les erreurs étrangères à la frontière qui connaît leur origine ; conserver une famille `SecretFailure` et une politique partagée de redaction. Préserver absence/verrouillage/corruption ; distinguer dérivation et signature. Retirer les conversions artificielles `Err → StateError → catch-all` des consommateurs touchés. Examiner également le catch général du [parser de liste](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/data/fss_datasource.dart:443), après correction du retry.

Deux contrôles de redaction restent nécessaires :

- **Défaut exécuté dans l’app :** [Failure.toString](/home/nicolas/Cage/repos/BULL/packages/primitives/lib/src/failure.dart:17) inclut `logMessage`. Le test `transaction_error_surface_test` montre qu’un message étranger avec token ressort dans une failure. C’est le seul échec applicatif après correction de l’environnement SQLite ; il bloque les checks de livraison même si le fichier est dans `primitives`.
- **Écart de politique dans le package :** [LiquidSigner](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/crypto/signers/liquid_signer.dart:66) journalise directement `LwkError.msg`. N4 ne montre aucune fuite de secret — seulement `Base64(InvalidLength)`. Ce contrôle ne justifie pas d’autoriser tous les messages étrangers futurs : utiliser des catégories ou champs explicitement autorisés et tester les sentinelles sensibles.

**Acceptation :** failures typées et stables, erreurs de programmation non absorbées, aucun message sensible dans les sorties/logs testés, test applicatif rouge réparé. Un grep « aucune failure construite dans public » ne suffit pas à prouver ce comportement.

### R8 — Inventorier la vraie surface publique et aligner la documentation

**Constat exécuté P9 :** sur une copie du package, j’ai ajouté `SecretMaterial` à l’export transitif et une méthode retournant `Future<Result<String, SecretFailure>>` à `Secret`. Un consommateur compile en nommant le type exporté ; **les six invariants originaux restent verts**. Le vrai package n’a pas été muté.

Références : [invariants_test.dart](/home/nicolas/Cage/repos/BULL/packages/secrets/test/invariants_test.dart:96), [types.dart](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/public/types.dart:10), [README](/home/nicolas/Cage/repos/BULL/packages/secrets/README.md:8).

**Travail :** suivre les exports transitifs, idéalement avec le modèle résolu de l’analyzer, et fixer une liste blanche. Inventorier chaque opération publique, quel que soit son type de retour. Documenter séparément données sensibles et capacités :

| Surface | Ce qui sort / ce qui est délégué |
|---|---|
| `bip85Hex`, `bip85Mnemonic` | Entropie ou mnemonic enfant, sensibles et destinées à être utilisées ailleurs. |
| `swapKey` | Credential dédié aux swaps, dont xprv et mnemonic. |
| `databaseKey` | Clé de chiffrement déléguée au module propriétaire de la base. |
| `backupVault` | Fichier chiffré **et sa clé** ; leur réunion permet l’ouverture. |
| `psbtSigner` | Capacité de signer ; durée de vie à borner. |
| `revealWords` / `MnemonicView` | Sortie brute encore présente / affichage interne au package. `RevealReason` marque une intention, pas une autorisation. |

Corriger « rien d’exporté ne porte de matériel », « exactement trois sorties », « tout crypto est pur », « une lecture ne charge aucun matériel », les mentions de verrou « process-wide » et les références périmées. Le verrou Dart statique appartient à **un isolate** ; plusieurs isolates/engines ne sont pas couverts. `readAll` charge les valeurs du magasin avant filtrage. Expliquer les limites mémoire sans prétendre garantir l’effacement des `String` ou des copies FFI.

**Acceptation :** une addition d’export ou de méthode inconnue rend les tests rouges ; les sorties voulues sont documentées avec destinataire et durée de vie. README et dartdoc courts, compréhensibles et cohérents avec les garanties effectivement testées.

### R9 — Mettre les preuves importantes dans le dépôt et rendre les checks verts

**Travail :** conserver les goldens/vecteurs ; transférer les reproductions utiles en véritables tests de non-régression. Les sondes qui démontrent un défaut doivent changer d’attente pour vérifier sa correction.

- Formats de vault **OLD/NEW** : fixtures publiques et ouverture/dérivation dans les tests du package ; Tor, récupération distante et création de wallets dans l’intégration applicative. Réutiliser les fixtures existantes avec provenance explicite.
- Signatures : fixtures publiques BDK et LWK sans fonds ni diffusion, exécutées en CI ; matrices de scripts/réseaux/passphrases et cas de signature partielle utiles aux consommateurs. Les tests financés sont une couche supplémentaire.
- UI, concurrent imports, chemins BIP85, corruption et redaction : critères des lots ci-dessus.
- Conserver le formatage désormais corrigé, inclure les nouveaux fichiers actuellement non suivis dans la revue et la vérification, puis exécuter `make checks` sur le candidat final.

**Acceptation :** tous les checks requis passent sur un état identifié, et la matrice appareil/upgrade de R4 est jointe à la validation release. Le nombre de tests seul n’est pas un critère de couverture.

## 3. Autres recommandations et décisions d’architecture

### Identité complète et absence d’écrasement — avant release, accord explicite

[storeSecret](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/data/fss_datasource.dart:146) écrit toujours sans comparer à l’entrée existante. Le fingerprint BIP32 est sur 32 bits ; la vérification ajoutée à la lecture ne distingue pas deux identités ayant le même fingerprint. [BIP32](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki) demande de gérer les collisions, source vérifiée le 15 septembre 2026.

Je recommande un refus d’écrasement d’une identité différente, avec comparaison d’une identité complète à l’intérieur du package et lecture/comparaison/écriture atomiques. Ne pas renommer ou supprimer automatiquement une entrée historique. **Aucune collision cryptographique n’a été générée pendant cet audit** ; ce risque est distinct de P7, qui utilise exactement les mêmes mots et n’exige aucune collision. **Claude a confirmé explicitement ce rang avant release dans son entrée 19:55.** Cette protection rejoint le lot de persistance, avec une régression indépendante de la course P7.

### Listing cohérent et indication de résultats incomplets

P4 confirme que le checksum est vérifié au listing uniquement lorsqu’une passphrase impose une dérivation supplémentaire ([`_describe`](/home/nicolas/Cage/repos/BULL/packages/secrets/lib/src/data/secret_repository.dart:119)). Valider les mots sans dériver le seed dans les deux cas. Distinguer « aucun secret » de « des entrées ont été ignorées » afin que l’appelant puisse proposer un diagnostic approprié. Ne pas supprimer ces entrées à cette occasion.

### Contrat des clés de base

Le traitement non destructif d’une valeur vide/corrompue est bon. En revanche, `databaseKey` ne sait pas si une base existe déjà ; un `null` autorise une création. Le module propriétaire de la base doit distinguer ouverture et création initiale, et décider de la récupération d’une paire base/clé illisible. Le commentaire selon lequel toute base est un cache reconstructible n’est pas une garantie du package générique.

Le datasource partagé de l’app refuse `seed_`, mais ne refuse pas encore le namespace des DEK ([filtre](/home/nicolas/Cage/repos/BULL/lib/core/storage/data/datasources/key_value_storage/impl/secure_storage_data_source_impl.dart:24)). Étendre la règle de propriété aux namespaces réellement revendiqués par `secrets`, en particulier avant utilisation des DEK par les modules. Ce constat porte sur les chemins d’accès autorisés par le code ; il ne prétend pas isoler deux bibliothèques Dart partageant le même processus d’un attaquant contrôlant l’application.

### Conventions du dépôt et simplicité interne

La façade concrète, les fonctions déterministes avec vecteurs et les adaptateurs distincts par chaîne sont à conserver. Une interface commune Bitcoin/Liquid n’apporterait rien si elle masque leurs contrats différents.

Les règles 2/6 exigent toutefois un contrat de repository dans `domain`, une implémentation dans `data` et des usecases d’orchestration. L’état actuel les contourne. Proposer ce refactoring comme un lot autonome avec la frontière `Result`, ou faire acter une dérogation ciblée par Nicolas ; ce n’est pas une exception déjà acquise. L’injection interne permet les tests sans remettre le keystore au caller. Garder les signatures publiques indépendantes du repository concret.

Actualiser la carte `FEATURES.md` selon les dépendances finales. `implementation_imports` est déjà activé par les lints hérités et le `make analyze` fatal aux infos passe : ajouter simplement une ligne d’activation n’est pas une correction de fond.

### Améliorations différables

- Lot BIP85 pour matérialiser une fois et dériver N valeurs ; mesurer le coût sur appareil avant d’ajouter un cache. Ne pas faire ressortir le xprv pour contourner les N lectures.
- Alléger le double coût `fetch` puis opération et les matérialisations inutiles pour vérifier/afficher des mots, sans prolonger la durée de vie du seed.
- Corriger les métadonnées de package, le changelog, les liens de documentation et les libellés de logs.
- Nettoyer le retrait de préfixe du chemin RecoverBull et les commentaires devenus inexacts. Ces finitions n’ont pas le même rang que restauration, signature ou persistance.

## 4. Résultats de vérification

| Vérification | Résultat et limite |
|---|---|
| SDK | FVM Flutter 3.44.9 / Dart 3.12.2. |
| `make analyze` | **Vert sur le workspace initial et final** ; dernier passage : 7,1 s. |
| Tests `secrets` | **112/112 verts**, avant et après les corrections UI/retry. |
| `make unit-test` avec SQLite résolu | **1951 succès, 1 échec** dans la suite app : `transaction_error_surface_test`. Le make s’arrête avant la boucle des packages. |
| `make fix-check` | Vert : `Nothing to fix!`. |
| `make format-check` | **Vert après correction de Claude** ; initialement 25 fichiers suivis à formater. Contrôle séparé du package, y compris non-suivis : 46 fichiers, 0 changement. Mes commandes `--output=none` n’ont rien modifié. |
| `make bull-ui-check` | Vert. |
| S1/S2 | **3/3** : deux signatures BIP84 vérifiées ; callback encore capable de signer après suppression. |
| P1–P6, état initial | **6/6** après correction de la sonde P1 : contrôles de vault/DEK, défauts retry/passphrase/listing et ancien état du widget. |
| P7/P8/P9 + invariants | **9/9** : deux défauts de consommateurs et une exportation indue passent ; les six invariants ne détectent pas la mutation de la copie. |
| N1–N4 + W1, état corrigé | **5/5** : métadonnées Liquid, racines historiques Liquid/Boltz, refus PSET/nettoyage, correction UI. |
| Frontières, état corrigé | **5/5** ; dont P2 : `StateError` propagé au premier appel. |

La première suite app avait 176 échecs avec le chargeur incapable de trouver `libsqlite3.so`. Un lien temporaire vers la bibliothèque installée a ramené ce nombre à un. Ces 176 échecs ne sont donc pas retenus comme défauts du produit. De même, les premières erreurs de compilation des sondes ou de chargement de la bibliothèque LWK ont été corrigées dans les seuls fichiers/environnements temporaires ; seuls leurs résultats aboutis étayent les conclusions natives.

**Limites :** aucune signature PSET valide vérifiée ; pas de matrice complète BIP44/BIP49/Payjoin ; aucun essai de keystore réel sur Android/iOS, d’upgrade historique ou d’interruption native ; pas de preuve de zéroïsation ; pas de qualification de sécurité des dépendances cryptographiques elles-mêmes. Les contrôles natifs Linux ne prouvent pas les propriétés du cycle de vie mobile.

## 5. Ordre de réalisation proposé

1. **Acter les contrats qui changent le comportement utilisateur** : backup avec passphrase, racines historiques Liquid/swaps, cohorte Android supportée, invalidation des signers et récupération des bases.
2. **Installer les tests de régression avant chaque correction** : fixtures historiques et sondes de cet audit adaptées en critères d’acceptation.
3. **Corriger les comportements sensibles** : session de signature, dernier affichage brut/protection, concurrence des imports, validation des chemins et refus d’écrasement.
4. **Achever les frontières internes et la redaction**, avec contrats de repository conformes ou dérogation explicitement actée.
5. **Fixer l’inventaire public et réécrire la documentation** sur le comportement final ; mettre la carte des dépendances à jour.
6. **Valider le candidat de release** : checks verts, tests natifs permanents et matrice d’upgrade/appareil. Découper en lots logiques et commits atomiques quand leurs dépendances le permettent.

## 6. Accord avec Claude

Accords explicites déjà présents dans le fil : défauts d’invariants, contrat de passphrase, durée de vie du signer, réparation et tests du widget, frontière de repository, fixtures historiques dans le package, tests publics de signature en CI et caractère bloquant de la suite applicative rouge. Les correctifs UI/retry proposés par Claude ont été vérifiés indépendamment.

Le prétendu désaccord « fss9 inconditionnel ou conditionnel » est clarifié : une décision explicite peut modifier les versions supportées ; elle ne vaut pas preuve de compatibilité. Le candidat actuel reste non validé pour la cohorte historique.

**Accords complémentaires explicites, entrée Claude 18:50 :** P7 est bloquant malgré son antériorité ; les derniers affichages bruts rejoignent les conditions de livraison ; le critère fss9 et le regroupement par comportement sont acceptés. P8 est corrigé ; le signal de liste partielle reste une décision de contrat.

**Accord final :** Claude confirme expressément l’anti-écrasement avant release et le contrat à préciser pour les lignes BIP85 ignorées (entrée 19:55). Codex accepte R1–R9 de la synthèse commune ; l’inventaire des travaux converge.

**Décisions de conception encore ouvertes :** portée des sauvegardes avec passphrase, compatibilité de la cohorte Android, propriétaire et invalidation des sessions de signature, récupération des paires base/clé, signal des listes partielles et éventuelle dérogation ciblée à la règle 6. La correction d’une fuite démontrée n’est pas une option à arbitrer contre la lisibilité des logs. La présence d’entrées historiques incohérentes en production n’a pas été évaluée.

La relecture du document court de Claude a aussi demandé de préciser la provenance de sa configuration SQLite, de ne pas imposer un commit unique sans examen des dépendances, et de prévoir un affichage scellé approprié au credential de swap : le `MnemonicView` actuel afficherait les mots maîtres du `Secret`. **Ces quatre précisions ont été acceptées et appliquées par Claude dans son entrée 20:10.** La [synthèse commune](/tmp/secrets-architecture-review/RAPPORT_FINAL_COMMUN.md) constitue la version courte du plan. Les décisions de Nicolas rapportées par Claude restent attribuées à son message ; aucune absence de réponse n’a été interprétée comme un accord.

## 7. Preuves et reproduction

Tous les fichiers de sonde et journaux sont dans [/tmp/secrets-release-audit-20260915](/tmp/secrets-release-audit-20260915). Les commandes et distinctions entre sondes historiques et finales sont dans [REPRODUIRE.md](/tmp/secrets-release-audit-20260915/REPRODUIRE.md). Ils ne contiennent que des fixtures publiques et peuvent être transférés dans les tests du dépôt après adaptation des attentes.

- [Signatures et preuve de conservation du callback](/tmp/secrets-release-audit-20260915/signature_probes_test.dart) — [sortie](/tmp/secrets-release-audit-20260915/signature-probes.log).
- [Course d’import](/tmp/secrets-release-audit-20260915/import_race_probe_test.dart), [chemins BIP85](/tmp/secrets-release-audit-20260915/bip85_path_probe_test.dart), [mutation d’invariants](/tmp/secrets-release-audit-20260915/invariant_mutation_probe_test.dart) — [sortie commune](/tmp/secrets-release-audit-20260915/consumer-invariant-probes.log).
- [Dérivations natives](/tmp/secrets-release-audit-20260915/native_derivation_probes_test.dart), [widget corrigé](/tmp/secrets-release-audit-20260915/widget_final_checks_test.dart) — [sortie](/tmp/secrets-release-audit-20260915/native-widget-final.log).
- [Frontières / backup / corruption — état final](/tmp/secrets-release-audit-20260915/boundary_final_checks_test.dart) — [sortie finale](/tmp/secrets-release-audit-20260915/boundary-final.log), [sortie initiale des défauts](/tmp/secrets-release-audit-20260915/boundary-widget-probes-v2.log).
- [Suite app finale avec SQLite](/tmp/secrets-release-audit-20260915/unit-test-final.log), [package final](/tmp/secrets-release-audit-20260915/package-tests-final.log), [analyse finale](/tmp/secrets-release-audit-20260915/analyze-final.log), [fix/format initial](/tmp/secrets-release-audit-20260915/remaining-checks.log), [format final](/tmp/secrets-release-audit-20260915/format-final.log).

Les signatures de S1/S2 utilisent un préimage construit conformément à [BIP143](https://github.com/bitcoin/bips/blob/master/bip-0143.mediawiki), vérifié le 15 septembre 2026. Le protocole de discussion et les validations de Claude restent dans [ECHANGE.md](/tmp/secrets-architecture-review/ECHANGE.md).
