# Architecture de `secrets` — comparaison et proposition de discussion

Date : 2026-09-16. Auteur : Codex. Statut : proposition à confronter, aucune architecture cible approuvée dans ce document.

## 1. Résumé à partager

**Critère de décision retenu avec le développeur : le coût déterminant est celui de comprendre et de vérifier une modification.**

Le package doit permettre de trouver rapidement un comportement, comprendre les règles dont il dépend, identifier les conséquences possibles d'un changement et retrouver les preuves de son bon fonctionnement.

Ma préférence actuelle est une **organisation par capacités avec un socle commun explicite** : `derivers/`, `signers/`, `backups/`, puis `storage/` pour la persistance, `domain/` pour les concepts et invariants communs et `public/` pour le contrat consommateur. Cette préférence est une appréciation du package actuel, à vérifier sur des scénarios de modification ; les tableaux ne constituent pas un classement mesuré.

Les couches restent une alternative solide pour une équipe qui bénéficie de leur uniformité. Les ports deviennent intéressants lorsqu'une frontière doit être testée ou substituée indépendamment. Les slices par opération sont pertinentes lorsque les cas d'usage deviennent assez autonomes pour évoluer séparément.

**La syntaxe `secret.derive.bip85.hex(...)` est compatible avec toutes ces options.** L'ergonomie publique et l'organisation interne se décident séparément, puis doivent raconter la même histoire.

Ce document résume la discussion d'architecture et la lecture des sources. Il ne remplace pas l'audit de release. Claude travaille sur l'implémentation : seul ce document est ajouté, sans modification du package ni exécution de ses tests. Les descriptions du code sont des observations de l'état de travail local, pas une validation de ses garanties.

## 2. Contexte et priorités

### Ce que le développeur recherche

| Priorité | Conséquence pour la conception |
|---|---|
| Compréhension rapide | Les noms indiquent où se trouve un comportement et ce qu'un fichier possède. |
| Auditabilité | L'accès au matériel sensible, les sorties autorisées et la durée de vie des ressources ont des propriétaires identifiables. |
| Expérience développeur | L'API expose les intentions : dériver, signer, sauvegarder, ouvrir une base. |
| Maintenance | Une modification locale demande peu de connaissances simultanées ; une règle commune a un endroit reconnu. |
| Pragmatisme | Une interface, un dossier ou un intermédiaire doit protéger un contrat ou simplifier une lecture réelle. |
| Liberté architecturale | Une amélioration démontrée de compréhension peut justifier un écart aux conventions BULL, selon l'instruction explicite du développeur. |

La discussion ne vise donc pas à imposer des interfaces abstraites partout, à multiplier les usecases, ni à choisir un nom d'architecture pour lui-même. Leur utilité doit être évaluée sur une frontière concrète.

Les références locales restent [AGENTS.md](../AGENTS.md), [ARCHITECTURE.md](../ARCHITECTURE.md) et [FEATURES.md](../FEATURES.md). L'option A est la plus proche de leurs conventions. Les autres options demanderaient de documenter explicitement l'exception retenue pour `secrets`, afin que les prochains agents ne tentent pas de la « corriger » automatiquement.

### Ce que cette comparaison ne déduit pas

Un dossier ne garantit ni l'absence de fuite, ni la fermeture d'un objet natif, ni l'atomicité d'une écriture. Une fonction déterministe peut produire un secret. Une classe sans champ peut utiliser du hasard ou des fichiers. La sécurité dépend des contrats et de leur vérification, dans chaque option.

## 3. Point de départ : les ambiguïtés actuelles

Lecture locale du 2026-09-16, branche `feat-secrets-human`, HEAD `7ca783e1a`, avec des modifications non commitées. Ce commit ne suffit pas à reproduire les observations ; Claude peut faire évoluer ces fichiers pendant la discussion.

Arbre simplifié observé :

```text
lib/src/
├── public/                    # Secrets, Secret, syntaxe groupée, guard, MnemonicView
├── domain/                    # SecretInfo, SecretMaterial, DatabaseKey, failures…
├── data/
│   ├── secret_repository.dart
│   ├── database_keys.dart
│   ├── fss_datasource.dart
│   └── models/
├── crypto/
│   ├── derivers/
│   ├── signers/
│   ├── backups/
│   └── generator.dart
└── testing/
```

| Observation vérifiée | Pourquoi elle compte |
|---|---|
| [extensions.dart](../packages/secrets/lib/src/public/extensions.dart), lignes 27–38, expose `derive`, `sign`, `backup`, `reveal`. | Le vocabulaire des capacités existe déjà côté consommateur. |
| [secret.dart](../packages/secrets/lib/src/public/secret.dart), à partir de la ligne 54, orchestre chargement et opérations derrière `guard`. | La façade tient déjà un rôle d'orchestration ; ajouter des usecases déplacerait ce rôle. |
| [database_keys.dart](../packages/secrets/lib/src/data/database_keys.dart), lignes 33–43, récupère ou crée un modèle persisté et retourne une `DatabaseKey`. | `DatabaseKeys` joue un rôle de repository de clés, même si son nom ne le précise pas. |
| [secret_repository.dart](../packages/secrets/lib/src/data/secret_repository.dart), `_materialize` et `_fingerprint`, réalise aussi des calculs BIP39/BIP32. | `crypto/` n'est pas le périmètre de toute la cryptographie du package. |
| [bitcoin_signer.dart](../packages/secrets/lib/src/crypto/signers/bitcoin_signer.dart), lignes 30–45, construit un wallet BDK capturé par un callback. | La signature implique une ressource et une durée de vie, au-delà d'un calcul. |
| [liquid_signer.dart](../packages/secrets/lib/src/crypto/signers/liquid_signer.dart), `signPset`, utilise un répertoire temporaire ; [generator.dart](../packages/secrets/lib/src/crypto/generator.dart) appelle BDK. | `crypto/` rassemble aussi des intégrations avec effets et une génération aléatoire. |
| [database_key.dart](../packages/secrets/lib/src/domain/database_key.dart), lignes 36–55, contient un invariant de longueur, des copies défensives et une représentation SQLCipher. | Un même fichier rassemble une valeur du domaine et une commodité d'intégration. Leur séparation éventuelle est une décision distincte. |

### `crypto` est-il du domaine métier ?

Une partie peut l'être : règles de dérivation, identité attendue, compatibilité des passphrases. D'autres éléments sont de l'orchestration ou de l'intégration native. Le sujet cryptographique ne détermine pas à lui seul la responsabilité architecturale.

`crypto/` pourrait rester pertinent si son contrat était explicitement « adaptateurs vers les moteurs cryptographiques ». Ce serait un autre choix que « toutes les opérations sur les secrets ». Renommer simplement ce dossier en `services/` apporterait peu d'information : le mot ne précise ni les capacités ni les effets autorisés.

### Que faire de `DatabaseKeys` ?

Le nom **`DatabaseKeyRepository`** expliciterait son rôle dans l'organisation actuelle. Le placer dans `data/` ou `storage/` est cohérent tant qu'il possède l'accès aux clés persistées et leur conversion en valeurs utilisables. Cette lecture rejoint le rôle général de médiation avec les objets persistés décrit dans le catalogue [Repository](https://martinfowler.com/eaaCatalog/repository.html) ; le nom proposé reste notre adaptation au code local.

Un dossier autonome `database_keys/` deviendrait utile si le sujet acquiert plusieurs opérations propres : création, ouverture, rotation et invalidation. Ces opérations sont des possibilités de structuration, pas des fonctionnalités demandées ici.

## 4. Trois dimensions à distinguer

| Dimension | Question | Exemples |
|---|---|---|
| Navigation | Où chercher le comportement ? | Couches techniques, capacités, opérations individuelles. |
| Dépendances | Qui peut connaître et appeler quoi ? | Dépendances vers le domaine, ports, confinement des bibliothèques natives. |
| Exécution | Où se produisent les effets et qui les termine ? | Keystore, hasard, fichiers temporaires, sessions natives. |

Les options ci-dessous combinent ces dimensions différemment. Une organisation par capacités peut employer des ports sur certaines frontières. Une organisation par couches peut garder des calculs purs. Les comparaisons portent sur les arbres proposés, pas sur des incompatibilités théoriques entre écoles.

Dans les arbres, les fichiers sont illustratifs et les listes abrégées. Les noms nouveaux représentent des rôles possibles ; leur présence n'implique ni une classe par méthode ni une création systématique de fichiers.

## 5. Les quatre options

### A — Couches explicites, proche de la convention BULL

Principe : chaque rôle a un emplacement uniforme. Les règles restent dans le domaine, l'orchestration dans les usecases et les intégrations dans `data/`. Le sens des dépendances importe davantage que le nombre de couches : c'est le principe central de [The Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html).

```text
lib/src/
├── public/
│   ├── secrets.dart
│   ├── secret.dart
│   ├── extensions.dart
│   └── mnemonic_view.dart
├── domain/
│   ├── entities/               # SecretInfo, SecretMaterial, DatabaseKey…
│   ├── repositories/
│   │   ├── secret_repository.dart
│   │   └── database_key_repository.dart
│   ├── usecases/
│   │   ├── sign_psbt_usecase.dart
│   │   └── create_backup_usecase.dart
│   └── bitcoin_signing_port.dart
├── data/
│   ├── secret_repository_impl.dart
│   ├── database_key_repository_impl.dart
│   ├── models/
│   └── datasources/
│       ├── secure_storage_datasource.dart
│       ├── bdk_signing_datasource.dart
│       └── recoverbull_datasource.dart
└── testing/
```

Flux illustratif : façade → usecase → contrat du repository ou de signature → implémentation. Une opération sans persistance n'a pas besoin d'un repository artificiel ; un contrat de signature peut exprimer cette autre responsabilité.

**Intérêt local :** navigation prévisible pour l'équipe BULL et emplacements reconnus pour validation, conversion et intégrations.

**Coût local :** comprendre une capacité demande de traverser plusieurs emplacements. Les intermédiaires qui ne font que transmettre doivent apporter une frontière réellement utile.

Le guide [Flutter — Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) recommande repositories, injection et tests des composants. Il considère la couche de domaine/usecases comme conditionnelle. L'obligation systématique de usecases et certains emplacements de cet arbre viennent de BULL, pas du guide Flutter.

### B — Ports et adaptateurs explicites

Principe : le cœur définit les capacités qu'il requiert ; les intégrations les implémentent. Un port est un contrat nommé selon son but, par exemple signer une transaction. La présentation d'[Alistair Cockburn sur l'architecture hexagonale](https://alistaircockburn.com/Talk%202025-11%20Hexagonal.pdf) décrit aussi le coût des interfaces et de l'assemblage.

```text
lib/src/
├── public/                    # Façade, syntaxe groupée, UI scellée
├── application/
│   ├── sign_psbt.dart
│   ├── create_backup.dart
│   └── ports/
│       ├── secret_store.dart
│       └── bitcoin_signing.dart
├── domain/                    # Valeurs et règles indépendantes des moteurs
├── infrastructure/
│   ├── keystore/
│   │   ├── secure_secret_store.dart
│   │   └── models/
│   ├── bdk/
│   │   └── bdk_bitcoin_signer.dart
│   ├── lwk/
│   │   └── lwk_liquid_signer.dart
│   └── recoverbull/
│       └── recoverbull_backup.dart
├── composition.dart           # Assemble les implémentations internes
└── testing/
```

Dépendances de code : application → ports/domaine ; infrastructure → ports/domaine. Le point d'assemblage connaît les implémentations. L'application n'importe pas les adaptateurs qu'elle utilise à l'exécution.

**Intérêt local :** faire apparaître précisément les contrats avec le keystore et les moteurs natifs, et tester les règles autour de ces contrats.

**Coût local :** davantage de contrats et d'assemblage à lire. Un port trop large masque le protocole réel ; un port par petite fonction multiplie les intermédiaires.

L'injection peut rester entièrement interne au package : elle n'exige pas que l'application fournisse ou manipule le keystore. Cette option ne nécessite pas de généraliser Bitcoin et Liquid dans une interface artificiellement commune.

### C — Capacités visibles et socle commun explicite

Principe proposé pour `secrets` : chercher les traitements par leur intention, avec un emplacement commun pour la persistance, les valeurs et l'entrée publique.

```text
lib/src/
├── public/
│   ├── secrets.dart
│   ├── secret.dart
│   ├── extensions.dart
│   ├── guard.dart
│   ├── types.dart              # Exports publics explicites
│   └── mnemonic_view.dart
├── domain/
│   ├── secret_info.dart
│   ├── secret_material.dart    # Interne, non réexporté
│   ├── secret_failure.dart
│   ├── database_key.dart
│   └── encrypted_vault.dart
├── storage/
│   ├── secret_repository.dart
│   ├── database_key_repository.dart
│   ├── secure_storage_datasource.dart
│   ├── exceptions.dart
│   └── models/
│       ├── secret_model.dart
│       └── key_model.dart
├── derivers/
│   ├── bitcoin_deriver.dart
│   ├── liquid_deriver.dart
│   ├── bip85_deriver.dart
│   └── boltz_deriver.dart
├── signers/
│   ├── bitcoin_signer.dart
│   └── liquid_signer.dart
├── backups/
│   └── recoverbull_backup.dart
├── mnemonic_generator.dart
└── testing/
```

**Intérêt local :** préserver le vocabulaire déjà présent dans l'API, rendre le rôle des repositories lisible et limiter la redistribution initiale des comportements.

**Coût local :** cette structure n'isole pas automatiquement les règles des bibliothèques natives. Une capacité qui grossit doit distinguer son orchestration, ses règles et son adaptateur lorsque cela réduit le travail de compréhension.

Il s'agit d'une organisation hybride assumée : capacités pour les traitements, responsabilités partagées pour le socle. Elle n'est pas une application stricte des slices par cas d'usage de Bogard.

**Affinement de mon premier arbre proposé :** je conserve ici `domain/` plutôt qu'un `types/` général, car il contient des invariants et du matériel interne, pas seulement des types exportés. Je place aussi `DatabaseKeyRepository` dans `storage/` pour le périmètre actuel ; le dossier autonome `database_keys/` reste une possibilité de croissance, avec des dépendances à préciser. Le renommage `data` → `storage` n'est pertinent que si son contrat reste bien centré sur la persistance et la reconstitution des secrets.

Le renommage éventuel de `failures.dart` ou de `fss_datasource.dart` dans cet arbre est secondaire. Il ne faut pas lier tous les ajustements de noms à la décision structurante.

### D — Slices par opération

Principe : regrouper ce qui sert un cas d'usage précis. [Jimmy Bogard — Vertical Slice Architecture](https://www.jimmybogard.com/vertical-slice-architecture/) propose de limiter le couplage entre slices, tout en permettant à chaque slice de choisir une implémentation adaptée à sa complexité. Il souligne la nécessité de savoir refactorer lorsque la logique devient trop complexe.

```text
lib/src/
├── public/                    # Contrat consommateur commun
├── operations/
│   ├── import_secret/
│   │   └── import_secret.dart
│   ├── derive_bip85/
│   │   ├── derive_bip85.dart
│   │   └── bip85_request.dart
│   ├── sign_psbt/
│   │   ├── sign_psbt.dart
│   │   └── bdk_signing_session.dart
│   └── create_backup/
│       ├── create_backup.dart
│       └── recoverbull_codec.dart
├── domain/                    # Concepts effectivement communs
├── storage/                   # Accès partagé et règles atomiques
└── testing/
```

Le dossier d'une opération unique est montré pour rendre la granularité visible ; il peut rester un fichier tant qu'un regroupement n'est pas utile.

**Intérêt local :** suivre une opération complète et ses décisions sans naviguer d'abord par catégories techniques.

**Coût local :** plusieurs opérations de `secrets` partagent fortement leur matériel, leurs dérivations et leurs moteurs. Il faut décider précisément ce qui reste commun pour éviter de reproduire la gestion des secrets dans chaque slice.

Cette adaptation conserve un stockage partagé parce que ses garanties s'appliquent à plusieurs opérations. La différence avec C porte surtout sur la granularité : `signers/` rassemble une famille de comportements ; `sign_psbt/` raconte une opération.

## 6. Tableaux comparatifs

Les appréciations suivantes sont des hypothèses de travail pour ce package. Elles supposent des implémentations correctement réalisées et des tests équivalents. Aucune option ne gagne automatiquement en sécurité, performance ou qualité de test grâce à ses noms de dossiers.

### 6.1 Compréhension et expérience développeur

| Sujet | A — Couches | B — Ports | C — Capacités + socle | D — Opérations |
|---|---|---|---|---|
| Trouver une signature | Identifier le usecase, puis suivre son implémentation. | Identifier l'opération, son port et l'adaptateur. | Commencer dans `signers/`. | Commencer dans `sign_psbt/`. |
| Comprendre un parcours complet | Parcours entre rôles uniformes. | Parcours entre cœur, contrat et adaptateur. | Façade, capacité, stockage si nécessaire. | Parcours local à l'opération, puis dépendances communes. |
| Comprendre une règle partagée | Domaine et contrats centraux. | Domaine et ports centraux. | Socle explicitement limité. | Contrat commun à retrouver parmi les slices. |
| Familiarité pour l'équipe actuelle | Vocabulaire déjà prescrit par BULL. | Vocabulaire supplémentaire à expliquer. | Vocabulaire métier déjà visible dans l'API. | Granularité par cas d'usage à adopter. |
| API fluide | Compatible. | Compatible. | Compatible, avec noms internes proches. | Compatible, façade regroupant les opérations. |
| Risque de lecture dominant | Trop d'intermédiaires sans décision. | Trop de contrats ou contrats trop génériques. | Dossiers de capacités devenant trop larges. | Logique commune dispersée ou dupliquée. |

### 6.2 Audit des secrets et des effets

| Question d'audit | A — Couches | B — Ports | C — Capacités + socle | D — Opérations |
|---|---|---|---|---|
| Où le matériel est-il chargé ? | Repository, orchestré par usecase. | Adaptateur de stockage derrière un port. | Repository commun, appelé par l'orchestration publique ou interne. | Accès commun appelé par chaque opération. |
| Qui autorise une sortie sensible ? | Contrat public et règle du usecase. | Contrat entrant et règle applicative. | Contrat public ; politique locale à la capacité si nécessaire. | Contrat public et règle de l'opération. |
| Qui possède les objets natifs ? | Implémentation de l'intégration. | Adaptateur, derrière un contrat de durée de vie. | Signer ou session interne nommé explicitement. | Session de l'opération, avec partage éventuel du moteur. |
| Comment vérifier l'atomicité ? | Examiner le stockage partagé et ses appelants. | Vérifier le contrat atomique puis l'adaptateur réel. | Examiner le stockage partagé et ses appelants. | Vérifier que les slices réutilisent la même opération atomique. |
| Où traduire les erreurs étrangères ? | Frontière de l'intégration/repository. | Adaptateur vers le contrat du cœur. | Frontière concernée, avec politique commune de suppression des messages sensibles. | Frontière locale, avec même famille et politique communes. |
| Principal danger | Croire que la chaîne de couches suffit à garantir la custody. | Croire que le port prouve le comportement natif. | Laisser chaque capacité gérer différemment le matériel. | Répéter les règles sensibles dans plusieurs opérations. |

« Custody » désigne ici les règles de détention, d'accès, d'exposition et de durée de vie du matériel sensible. Le contrat doit aussi inventorier les capacités déléguées, comme signer, et les secrets dérivés. Il ne se résume pas à chercher des champs nommés `seed`.

### 6.3 Maintenance et tests

| Sujet | A — Couches | B — Ports | C — Capacités + socle | D — Opérations |
|---|---|---|---|---|
| Changer une règle d'une opération | Modifier son usecase/domaine ; adapter les contrats si besoin. | Modifier le cœur ; adaptateur concerné si le contrat change. | Modifier la capacité et son point d'appel. | Modifier la slice et son contrat public. |
| Remplacer BDK | Isoler les dépendances dans les implémentations concernées. | Remplacer les adaptateurs conformes aux ports existants. | Remplacer les implémentations des capacités utilisant BDK. | Remplacer les intégrations des slices concernées ou le moteur partagé. |
| Tester sans moteur natif | Doubles sur les contrats utiles. | Doubles des ports expressément prévus. | Frontière interne ciblée ou fonctions pures ; éviter les statiques partout si elles empêchent ces tests. | Tests de l'opération avec ses effets substitués. |
| Tester la réalité native | Tests d'intégration nécessaires. | Tests d'intégration nécessaires. | Tests d'intégration nécessaires. | Tests d'intégration nécessaires. |
| Travail simultané de plusieurs agents | Conflits possibles sur contrats et modèles partagés. | Conflits possibles sur ports et assemblage. | Travail répartissable par capacité ; socle à coordonner. | Travail répartissable par opération ; contrats communs à coordonner. |
| Changement transversal | Plusieurs implémentations à revoir malgré la règle centrale. | Plusieurs adaptateurs à revoir malgré le port central. | Plusieurs capacités à revoir malgré le socle commun. | Plusieurs slices à revoir malgré le contrat commun. |

Les doubles servent à vérifier les décisions autour d'un effet. Ils ne prouvent pas qu'une signature réelle est valide ni qu'un keystore fonctionne après une mise à jour système.

### 6.4 Effort de migration depuis l'état observé

| Option | Travail structurel | Risque principal du chantier | Quand la choisir |
|---|---|---|---|
| A — Couches | Extraire l'orchestration ; ajouter les contrats utiles ; répartir les intégrations. | Déplacer une décision ou une traduction d'erreur en modifiant son comportement. | L'uniformité des rôles améliore réellement les revues de l'équipe. |
| B — Ports | Définir les contrats, adapters et assemblage ; séparer règles et effets. | Concevoir des abstractions inadaptées aux bibliothèques natives. | Les tests isolés et l'indépendance de moteurs précis deviennent une difficulté récurrente. |
| C — Capacités + socle | Déplacer les groupes déjà existants ; clarifier les repositories et les dépendances. | Produire seulement un nouvel arbre sans clarifier les responsabilités. | La recherche par capacité résout la gêne actuelle avec peu de redistribution. |
| D — Opérations | Redistribuer façades et moteurs entre opérations ; identifier les dépendances communes. | Fragmenter le package et dupliquer des règles de custody. | Les opérations acquièrent des workflows assez autonomes pour évoluer séparément. |

Il n'y a pas d'estimation en jours : le code évolue en parallèle et les contrats de release peuvent encore modifier les frontières. À comportement constant, C semble demander le moins de redistribution parmi ces quatre propositions. Conserver l'arbre actuel en clarifiant les noms et responsabilités reste l'option de référence à battre.

### 6.5 Modifications concrètes pour départager les options

| Scénario | A — Couches | B — Ports | C — Capacités + socle | D — Opérations |
|---|---|---|---|---|
| Ajouter une dérivation BIP85 par lot | Usecase, contrat éventuel, moteur. | Opération et contrat de calcul si nécessaire. | API et `bip85_deriver`. | Slice `derive_bip85`. |
| Borner une session de signature | Usecase et contrat de signature, implémentation native. | Port de session et adaptateur natif. | Contrat de session et signer concernés. | Opération de signature et session associée. |
| Refuser une clé de base corrompue | Modèle/stockage, failure, propagation. | Adaptateur de stockage et contrat d'échec. | Modèle, repository, stockage partagé, failure. | Opération de clé et stockage commun. |
| Changer la sémantique d'une sauvegarde avec passphrase | Règle de domaine, usecase, format si nécessaire. | Règle applicative, contrat, adaptateur de format. | Contrat de backup et implémentation concernée. | Slice `create_backup` et chemin de restauration. |
| Auditer toutes les sorties sensibles | Surface publique puis parcours des couches. | Ports entrants puis implémentations pertinentes. | Surface publique puis capacités concernées. | Surface publique puis ensemble des slices. |

Ces parcours sont des projections, pas des comptages de fichiers nécessaires. Par exemple, un lot BIP85 n'exige un nouveau contrat que si la frontière actuelle ne l'exprime pas déjà.

## 7. Noyau fonctionnel et enveloppe avec effets : compatible avec les quatre options

L'approche [Functional Core, Imperative Shell](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) sépare les calculs sur des valeurs de l'enveloppe qui lit, écrit et interagit avec l'extérieur. Elle propose une discipline d'exécution qui peut s'appliquer à chacun des arbres.

Application proposée à `secrets` :

| Nature du code | Exemples | Vérification adaptée |
|---|---|---|
| Règles et transformations déterministes | Validation d'un chemin, décisions de compatibilité, conversion d'un format. | Cas limites, vecteurs de référence, fixtures historiques. |
| Effets de stockage | Lecture du keystore, écriture composée, refus de corruption. | Fake fidèle, concurrence contrôlée, tests sur plateforme. |
| Effets natifs et ressources | Construction d'un wallet, signature, répertoire temporaire, fermeture. | Tests des parcours d'échec et intégration avec le moteur réel. |
| Hasard et temps | Génération initiale, index aléatoire, date persistée. | Contrat explicite sur la source et tests adaptés, sans remplacer silencieusement l'algorithme historique. |

Une dérivation déterministe reste sensible si son résultat est une clé ou de l'entropie. La séparation des effets facilite le raisonnement ; elle ne rend pas les valeurs inoffensives.

## 8. Recommandation détaillée pour la discussion

### Retenir provisoirement C, avec des dépendances courtes et explicites

L'arbre C répond directement aux deux difficultés exprimées : retrouver les capacités sans interpréter `crypto`, et reconnaître le rôle de `DatabaseKeys`. Il conserve les éléments déjà compréhensibles du module et permet d'ajouter un port uniquement à une frontière qui le justifie.

Règles proposées :

1. **`public/` expose et compose.** Les wrappers fluides transmettent les paramètres ; une même opération possède une implémentation de comportement identifiable.
2. **`domain/` définit les valeurs et invariants communs.** Il ne dépend ni des intégrations natives, ni du stockage, ni des widgets. Sa présence sous `src/` n'implique aucune exportation publique.
3. **`storage/` possède la persistance et sa reconstitution.** Modèles persistés, namespaces, traductions du plugin et opérations atomiques restent regroupés. Ses signatures vers l'orchestration ne livrent pas les modèles de stockage.
4. **Les capacités reçoivent ce dont elles ont besoin.** Elles ne relisent pas le keystore à leur guise. Leur contrat précise les données produites, les effets et les ressources détenues.
5. **Les dépendances entre capacités sont limitées et orientées.** Par exemple, un backup peut utiliser une dérivation ; le deriver ne dépend pas en retour du backup. Un concept commun peut rejoindre le domaine lorsqu'il a une responsabilité claire.
6. **La politique de suppression des messages sensibles est commune.** La classification d'une erreur reste près de la frontière qui en connaît le sens. Conserver `guard` comme façade de cette politique est possible sans lui demander de deviner toutes les exceptions étrangères.

Parcours d'exécution illustratif, qui n'est pas un diagramme des imports :

```text
Appel public → orchestration de l'opération
               ├─ acquisition via le repository → keystore
               ├─ capacité → bibliothèque native si nécessaire
               └─ fin de l'opération ou transfert vers une session explicite
```

Le lecteur doit pouvoir répondre : qui possède le matériel à chaque étape, quelle sortie est autorisée et qui termine la session ? Un helper d'acquisition ne garantit pas à lui seul qu'une closure n'a rien capturé ni que la mémoire a été effacée.

### Ce qui ferait changer cette préférence

| Observation pendant la maintenance | Évolution à considérer |
|---|---|
| Plusieurs capacités répètent une orchestration sensible complexe. | Extraire cette orchestration avec un contrat explicite et ses tests. |
| Les règles sont difficiles à tester sans charger BDK/LWK. | Introduire un port ciblé pour cet effet ; envisager B si le besoin est généralisé. |
| Une capacité rassemble plusieurs workflows qui évoluent indépendamment. | La subdiviser par opération, en direction de D. |
| Les reviewers trouvent plus vite les décisions dans une chaîne uniforme. | Préférer A sur preuve de lecture, même si l'arbre comporte plus de fichiers. |
| Les nouveaux dossiers déplacent la confusion sans réduire les parcours. | Garder l'arbre existant avec des contrats et des noms mieux définis. |

### Questions de contrat à traiter indépendamment du rangement

Les règles de passphrase, la durée de vie des signers, le contenu des sauvegardes, la compatibilité des formats et le comportement face à une clé corrompue restent des décisions propres. Leurs états de correction doivent être relus dans l'audit et le code actuels ; ce document ne les marque ni terminés ni encore défectueux.

En particulier, le callback PSBT observé est **synchrone** (`String Function(String)`). Toute proposition de relire le keystore à chaque invocation doit d'abord vérifier le contrat natif de son consommateur. L'organisation choisie doit rendre cette contrainte visible ; déplacer le fichier ne la résout pas.

## 9. Comment décider sur des preuves

Comparer d'abord A et C sur les mêmes scénarios de la section 6.5. Garder B comme réponse à un besoin démontré d'indépendance des moteurs, et D comme réponse à une autonomie croissante des opérations.

| Mesure à relever lors d'une revue simulée | Ce qu'elle permet d'évaluer |
|---|---|
| Temps pour localiser la décision à modifier. | Qualité des noms et de la navigation. |
| Fichiers qu'il faut comprendre simultanément. | Charge de compréhension, au-delà du nombre total de fichiers. |
| Contrats partagés affectés. | Portée réelle du changement. |
| Endroits à relire pour exclure une sortie sensible. | Coût de l'audit global. |
| Tests capables de détecter une régression pertinente. | Qualité des preuves, au-delà du nombre de tests. |
| Résumé du reviewer sur les propriétaires et effets. | Compréhension effective du comportement. |

La simulation peut commencer sur papier avec les arbres et les fichiers actuels. Si un prototype est ensuite autorisé, conserver les mêmes comportements et tests de référence dans les deux variantes. Mesurer sur plusieurs lecteurs et scénarios réduit l'effet de la familiarité individuelle.

## 10. Migration envisageable après décision

1. **Fixer une version de référence.** Attendre ou coordonner les changements de Claude pour éviter de déplacer des fichiers en cours de correction.
2. **Écrire le contrat d'organisation retenu.** Rôles, dépendances autorisées, emplacement des effets et exceptions aux conventions BULL.
3. **Séparer les changements indépendants.** Clarification de `DatabaseKeys`, déplacements mécaniques, extraction de responsabilités et changements fonctionnels doivent rester identifiables et réversibles séparément.
4. **Préserver l'API, les formats et les résultats pendant les déplacements.** Maintenir la syntaxe fluide, les namespaces persistés, les vecteurs et les fixtures. Tout changement intentionnel de contrat reçoit sa propre revue.
5. **Mettre à jour les preuves d'architecture.** Références de fichiers, inventaire des exports et des capacités, tests des frontières et ressources ; privilégier des garanties vérifiables à des recherches de mots dans les sources.
6. **Vérifier selon le contenu du changement.** Utiliser les cibles make du dépôt pour l'analyse globale et les tests appropriés ; conserver les essais natifs et de plateforme lorsque leurs comportements sont touchés.

Ce plan décrit un chantier éventuel. La rédaction du document ne donne pas d'autorisation de lancer ce refactoring.

## 11. Bogard : résumé et portée de la référence

**[Vertical Slice Architecture — Jimmy Bogard, 19 avril 2018](https://www.jimmybogard.com/vertical-slice-architecture/)** : organiser autour des requêtes/cas d'usage, rapprocher ce qui change ensemble et adapter la complexité à chaque opération. L'auteur critique l'imposition uniforme de chaînes d'abstractions et demande une vraie discipline de refactoring. Il s'agit d'un retour d'expérience argumenté.

**[Vertical Slice Architecture Webinar Recording, and What's Next — Jimmy Bogard, 1er septembre 2026](https://www.jimmybogard.com/vertical-slice-architecture-webinar-recording-and-whats-next/)** : son argument est que l'aide des agents réduit fortement le coût d'écriture, tandis que vérifier et modifier le code demeure coûteux. Il défend des changements dont le contexte et les conséquences restent circonscrits. Ce court article ne fournit pas de comparaison expérimentale chiffrée.

La phrase directrice de notre discussion — « Le coût qui reste déterminant ici est celui de comprendre et de vérifier une modification » — est une formulation de notre critère pour `secrets`, pas une citation française littérale de Bogard. Le regroupement par capacités de C est notre adaptation ; D est plus proche de sa granularité par cas d'usage.

## 12. Sources et demande à l'agent relecteur

Sources primaires consultées le **2026-09-16** :

| Source | Usage dans ce document |
|---|---|
| [Flutter — Architecture recommendations](https://docs.flutter.dev/app-architecture/recommendations) | Repositories, injection, tests et caractère conditionnel de la couche de usecases. |
| [Robert C. Martin — The Clean Architecture, 2012](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) | Dépendances vers les règles internes et séparation avec les intégrations. |
| [Alistair Cockburn — Hexagonal Architecture, présentation de novembre 2025](https://alistaircockburn.com/Talk%202025-11%20Hexagonal.pdf) | Contrats selon leur but, adaptateurs et coût de l'assemblage. |
| [Jimmy Bogard — Vertical Slice Architecture, 2018](https://www.jimmybogard.com/vertical-slice-architecture/) | Organisation par cas d'usage et changement local. |
| [Jimmy Bogard — Webinar Recording, and What's Next, 2026](https://www.jimmybogard.com/vertical-slice-architecture-webinar-recording-and-whats-next/) | Discussion du coût de vérification avec les agents. |
| [Gary Bernhardt — Functional Core, Imperative Shell, 2012](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell) | Séparation calculs/effets ; description publique consultée, vidéo non visionnée. |
| [Catalogue de Martin Fowler — Repository](https://martinfowler.com/eaaCatalog/repository.html) | Rôle de médiation avec les objets persistés. |

Ces sources décrivent des principes et des retours d'expérience. Les arbres, comparaisons et recommandations pour `secrets` sont une analyse locale de Codex. Aucun accord de Claude sur cette proposition n'est présumé.

### Consigne réutilisable pour une seconde opinion

> Compare ces options à partir du code actuel de `packages/secrets`, en lecture seule. Priorise le coût de compréhension et de vérification d'une modification, l'ergonomie publique et l'audit des données sensibles. La conformité exacte aux dossiers BULL n'est pas un objectif en soi dans cette discussion. Vérifie les observations datées avant de les reprendre. Conteste les avantages supposés avec un scénario concret, un parcours de fichiers et les tests pertinents. Distingue l'organisation physique, le sens des dépendances et les contrats de comportement. Propose une préférence et indique les observations qui te feraient en changer. N'implémente rien sur la seule base de ce document.

**Conclusion proposée : rendre chaque capacité facile à retrouver, chaque garantie commune facile à contrôler et chaque changement facile à vérifier. L'arbre retenu doit se justifier par ce résultat.**
