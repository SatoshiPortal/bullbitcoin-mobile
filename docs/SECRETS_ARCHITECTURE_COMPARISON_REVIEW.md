# Architecture de `secrets` — seconde opinion

Date : 2026-09-16. Auteur : Claude, sur la consigne du §12 de [SECRETS_ARCHITECTURE_COMPARISON.md](SECRETS_ARCHITECTURE_COMPARISON.md). Lecture seule ; rien n'est implémenté sur cette base. Préférence en §5 ; ce qui la ferait changer en §6.

## 1. Observations datées — toutes vérifiées, une manquante

Les six observations du §3 sont exactes au 2026-09-16 (`extensions.dart` expose `derive`/`sign`/`backup`/`reveal` ; `secret.dart` orchestre derrière `guard` dès la ligne 54 ; `database_keys.dart` joue un rôle de repository ; `secret_repository.dart` calcule BIP39/BIP32 ; `bitcoin_signer.dart` capture un wallet ; `database_key.dart` mêle invariant, copie et `pragma`).

Il en manque une, et c'est la plus lourde pour la comparaison — **le graphe d'imports réel entre modules** :

```text
public  → crypto, data, domain
data    → domain
crypto  → domain
domain  → (rien)
testing → (rien)
```

Acyclique. `data` et `crypto` ne s'importent jamais. `domain` est la feuille commune. C'est exactement le sens que A, B et C exigent ; il est déjà là. Le document distingue trois dimensions (§4 : navigation, dépendances, exécution) puis compare surtout la première. Sur la deuxième, il n'y a rien à gagner : elle est acquise. Sur la troisième — qui possède les effets — aucun des quatre arbres ne change qui construit un wallet ou ouvre un répertoire temporaire ; c'est le travail de R2, pas d'un déplacement.

## 2. Les cinq scénarios du §6.5, parcourus dans l'arbre actuel

Fichiers réellement touchés aujourd'hui, et le test qui rougirait si le changement était mal fait. Puis ce que chaque option y change.

| Scénario | Arbre actuel : fichiers | Test qui garde | A | B | C | D |
|---|---|---|---|---|---|---|
| Lot BIP85 par chemins | `public/secret.dart`, `public/extensions.dart`, `crypto/derivers/bip85_deriver.dart` + entrée obligatoire dans `invariants_test` (inventaire) | `invariants_test` (rougit si la méthode n'est pas inventoriée), `derivation_vectors_test` | + usecase, + contrat éventuel | + opération, + port si le calcul est abstrait | **identique**, préfixe `derivers/` | `operations/derive_bip85/`, façade à recâbler |
| Borner une session de signature (R2) | `crypto/signers/bitcoin_signer.dart`, `crypto/signers/signers.dart`, `public/secret.dart`, `public/extensions.dart`, app `payjoin_wallet_adapter.dart` | **aucun aujourd'hui** — la sonde S2 de l'audit doit devenir un test, dans toutes les options | + usecase, + `bitcoin_signing_port` | + port de session, + adaptateur | **identique**, préfixe `signers/` | `operations/sign_psbt/` + session |
| Refuser une DEK corrompue (fait) | `data/models/key_model.dart`, `data/fss_datasource.dart`, `data/exceptions.dart`, `domain/failures.dart`, `public/guard.dart`, `public/types.dart` — 6 fichiers, 3 modules | `secret_repository_test` (groupe DEK), `redaction_test` (sentinelle) | + interface + impl séparées | + port de stockage + contrat d'échec | **identique**, préfixe `storage/` | `operations/database_key/` + stockage commun |
| Passphrase et sauvegarde (R1) | `public/secret.dart`, `public/secrets.dart`, `domain/` (résultat ou failure), `crypto/backups/recoverbull_backup.dart`, `data/boundary.dart`, + inventaire si le type de retour change | `vault_test` (vecteurs OLD/NEW), `invariants_test` | + règle de domaine + usecase | + règle applicative + contrat | **identique**, préfixe `backups/` | `operations/create_backup/` + chemin de restauration |
| Auditer toutes les sorties sensibles | `test/invariants_test.dart` (table des 13 opérations avec verdict), `public/secret.dart` (un fichier), `lib/secrets.dart` (30 noms) — trois fichiers, dont un qui **impose** | l'invariant lui-même | idem si la façade reste unique | idem | **identique** | se fragmente si les opérations portent leur propre contrat |

**Résultat** : pour les cinq scénarios, le parcours en C est le parcours actuel avec un préfixe de répertoire différent. Le document le reconnaît en §6.4 — « conserver l'arbre actuel en clarifiant les noms et responsabilités reste l'option de référence à battre » — puis ne le bat pas. A et B ajoutent des fichiers sans raccourcir un seul parcours. D raccourcit la lecture d'une opération et allonge celle du socle qu'elles partagent toutes.

## 3. Les avantages supposés de C, contestés

| Avantage énoncé | Ce que montre le code |
|---|---|
| « Trouver une signature : commencer dans `signers/` » | Aujourd'hui `crypto/signers/`. Un `ls lib/src/crypto` donne `backups/ derivers/ signers/ generator.dart`. Le niveau supplémentaire n'est pas un coût de compréhension ; il est nommé par capacité. |
| « Rendre le rôle des repositories lisible » | Le renommage `DatabaseKeys → DatabaseKeyRepository` le fait dans l'arbre actuel. `storage/` contre `data/` n'ajoute rien — et `data/` est le nom que le dépôt utilise partout. |
| « Limiter la redistribution initiale » | Zéro redistribution est moins que « la plus petite ». |
| « Préserver le vocabulaire de l'API » | Il est déjà préservé : `secret.derive.bip85.hex(...)` ne dépend d'aucun dossier. Le document le dit lui-même (§1). |

## 4. Le coût de C que le document ne compte pas

Deux invariants exécutables portent aujourd'hui sur `crypto/` **comme un seul module** :

- « les dépendances étrangères sont confinées au module qui les possède » — `bull_sdk` et `recoverbull` sous `crypto/`, nulle part ailleurs. Réponse à « où est le FFI ? » : un mot.
- « les imports inter-modules passent par l'entrée du module » — `crypto/crypto.dart` est la seule porte.

Éclater en trois répertoires racine donne trois propriétaires et trois portes. Exprimable — un ensemble à la place d'un nom — mais l'énoncé d'audit s'allonge, pour aucun gain de parcours. Et le chantier : quatre fichiers de `public/` à réimporter, les tests, le README § Modules, l'ensemble `modules` et la table `owner` de l'invariant — une quarantaine de sites, à comportement constant, **pendant que R7 réécrit `data/`**.

## 5. Préférence

**Garder l'arbre. Prendre les deux clarifications du document qui portent sur des rôles, pas sur des préfixes.**

1. `DatabaseKeys` → `DatabaseKeyRepository`. Le §3 a raison : c'est un repository par rôle, et le nom du dépôt pour ce rôle est celui-là.
2. Rendre `crypto/` honnête. Le document remarque, à juste titre, que `crypto/` rassemble des **adaptateurs vers les moteurs** — avec effets : répertoire temporaire, hasard, wallet construit — pendant que la seule cryptographie pure du package, le fingerprint d'identité, vit dans `data/secret_repository.dart`. Deux issues, l'une ou l'autre : énoncer le contrat de `crypto/` comme « adaptateurs vers les moteurs cryptographiques » ; ou déplacer `_fingerprint`/`_identify` dans `crypto/derivers/` pour que `data/` cesse de calculer. Je ferais la seconde **dans R7**, qui réécrit ce fichier de toute façon.

Pourquoi pas C : même parcours, invariant affaibli, quarante sites touchés au milieu d'un lot qui réécrit `data/`. Pourquoi pas A : hors jeu depuis la dérogation à la règle 6 du 15 septembre, que le document ne prend pas en compte ; et son sens des dépendances est déjà satisfait. Pourquoi pas B : aucune frontière n'a montré un besoin de substitution — les tests substituent sous le repository, à `FlutterSecureStoragePlatform.instance`, et les deux agents ont jugé cette couture plus fidèle qu'un port. Pourquoi pas D : le document le dit lui-même, les opérations partagent trop de matériel et de moteurs ; D dupliquerait les règles de custody qu'on vient de centraliser.

## 6. Ce qui me ferait changer d'avis

| Observation | Vers |
|---|---|
| La revue simulée du §9, menée sur **au moins deux lecteurs qui ne connaissent pas le package**, montre qu'ils ouvrent `crypto/` en attendant des mathématiques et s'y perdent | renommer `crypto/` en `engines/` ou `adapters/` — un nom, pas trois répertoires |
| Une seconde famille arrive — signer Ark, second format de backup — et `crypto/` dépasse une dizaine de fichiers | l'aplatissement de C commence à payer ; le faire alors, sur un arbre stable |
| R7 réduit `public/secret.dart` à du pur transfert et l'orchestration descend | le regroupement par opération de D devient pensable ; pas avant |
| L'invariant « FFI confiné à `{derivers, signers, backups}` » se lit aussi bien que « confiné à `crypto/` » sur des lecteurs réels | le coût du §4 tombe, et C ne coûte plus que le chantier |

La méthode du §9 est la bonne et le document ne l'exécute pas. La faire après R1–R9, sur l'arbre stabilisé, A retirée, C contre l'existant. Si C gagne sur des lecteurs réels, déplacer.

## 7. Réserve

Deux jours dans cet arbre : je ne suis pas un lecteur neutre, et la familiarité fait paraître courts des parcours qui ne le sont peut-être pas. C'est précisément ce que la mesure du §9 corrige, et pourquoi elle vaut plus que cet avis.
