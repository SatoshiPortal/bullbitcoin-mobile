# Faisabilite des Compact Block Filters (CBF)

Date de recherche : 2026-07-22 (UTC). Ce document est une etude ; il ne change pas le comportement de l'application et ne constitue pas encore une decision d'implementation.

## Decision provisoire

L'integration est techniquement faisable pour les wallets Bitcoin BDK, mais le go produit reste conditionnel au spike. CBF n'est pas un remplacement transparent d'Electrum : il introduit un modele de synchronisation P2P long, persistant et a progression, sans observation native du mempool. La V1 recommandee est foreground uniquement, opt-in, desactivee par defaut, avec Electrum conserve pour le broadcast. Aucun schema ou parcours utilisateur ne doit etre modifie avant le go/no-go du spike defini dans `docs/compact-block-filters-implementation-plan.md`.

CBF ne concerne pas Liquid : Bull utilise LWK pour Liquid, tandis que cette etude porte sur le wallet Bitcoin BDK.

## Etat actuel de Bull

| Sujet | Constat verifie | Impact CBF |
|---|---|---|
| Binding BDK | `bdk_dart` est une dependance transitive de `bull_sdk`, verrouillee a `1.0.0-rc.3`, revision `fbf8952e` dans `pubspec.lock`. | Aucune nouvelle dependance Dart n'est necessaire pour un spike ; l'API CBF est deja exposee par ce binding. |
| Synchronisation Bitcoin | `BdkWalletDatasource` execute exclusivement `ElectrumClient.fullScan()` dans un isolate (`lib/core/wallet/data/datasources/bdk_wallet_datasource.dart:83-120`, `:779-819`). | CBF est un second backend de synchronisation, pas un parametre de l'actuel client Electrum. |
| Persistance wallet | `BdkFacade` persiste le wallet BDK dans SQLite, avec un chemin par wallet. | CBF doit aussi posseder et sauvegarder son propre repertoire de donnees : headers et pairs ne sont pas dans le persister du wallet BDK. |
| Orchestration foreground | `SyncCoordinator` serialise des synchronisations courtes et n'expose qu'un succes/echec (`lib/core/sync/sync_coordinator.dart`). | Il faut un canal de progression dedie, a instance unique par wallet, plutot que de transformer arbitrairement le boolean actuel. |
| Taches de fond | `handler.dart` initialise un isolate et un locator independants ; les syncs appellent directement `SyncWalletUsecase` (`lib/core/background_tasks/handler.dart:19-103`). | Aucun CBF n'est ajoute a ce chemin en V1. Une experimentation background future devra prouver l'arret natif et la reprise sur chaque plateforme. |
| Fees | Les frais Bitcoin proviennent deja d'une API mempool compatible (`lib/core/fees/data/fees_datasource.dart:30-82`). | Aucune regression de l'estimation de frais lors du passage CBF. |
| Broadcast | Le broadcast Bitcoin utilise aujourd'hui `ElectrumClient.transactionBroadcast()` (`lib/core/blockchain/data/datasources/bdk_bitcoin_blockchain_datasource.dart:9-40`). | Le broadcast P2P CBF ne fournit pas la meme reponse de rejet synchrone ; ce flux doit rester Electrum ou obtenir une mitigation explicite. |

Le wizard de premier lancement est dans `lib/features/wizard/`, mais la creation/restauration de wallet est dans `lib/features/onboarding/` et les flux d'import. La question produit "activer CBF dans le wizard" doit donc etre tranchee : enregistrer une preference globale dans le wizard, puis l'appliquer lors de chaque creation/import, ou ajouter le choix au parcours de wallet. Pour ne pas demander un choix de backend avant que l'utilisateur ait un wallet, le plan recommande une preference de confidentialite dans le wizard suivie d'une confirmation contextualisee dans le parcours wallet.

## Ce que CBF apporte

BIP157 definit le protocole P2P de distribution et de verification des filtres ; BIP158 definit les filtres compacts "basic". Le client telecharge et verifie une chaine d'entetes et d'engagements de filtres, teste localement ses scripts, puis ne telecharge les blocs/transactions pertinents que lorsqu'un filtre correspond. Le serveur ne recoit donc pas la liste complete des scripts/adresses du wallet comme avec Electrum.

Dans `bdk_dart`, cette fonction est fournie par `bdk_ffi` et `bdk_kyoto`. L'API exposee au binding Dart est de type client/noeud :

```dart
final components = CbfBuilder()
    .peers(peers)
    .connections(connections)
    .dataDir(dataDir)
    .scanType(scanType)
    .socks5Proxy(proxy)
    .build(wallet: wallet);

components.node.run();
final info = await components.client.nextInfo();
final update = await components.client.update();
wallet.applyUpdate(update: update);
```

Les noms ci-dessus ont ete verifies contre le binding `bdk_dart` `1.0.0-rc.3` verrouille par Bull. `socks5Proxy` existe dans l'API mais n'est pas utilise en V1 (voir la section Tor : sans `only_configured_peers`, il ne suffit pas a empecher le DNS clearnet). `nextInfo()` est une attente asynchrone a interroger en boucle, pas un `Stream` Dart : `ProgressInfo` contient `chainHeight` et `filtersDownloadedPercent`; le mapper doit aussi traiter `ConnectionsMetInfo`, `SuccessfulHandshakeInfo` et `BlockReceivedInfo`. Les avertissements sont lus separement avec `nextWarning()`. `shutdown()` annule le noeud mais un second appel natif leve `NodeStoppedCbfException`; l'idempotence doit etre fournie par le wrapper Bull. Il n'existe pas de pause/reprise en memoire : une nouvelle instance reprend grace au `dataDir` persistant.

Le noeud lance un thread natif detache et son runtime Tokio dans le processus courant. Il n'enregistre pas de service Android ou iOS. Le comportement exact lors de la suspension et de la terminaison du processus doit etre confirme sur appareils reels pendant le spike ; la V1 ne doit donc contenir aucune promesse de background.

## Limites et maturite de bdk-dart

- `bdk_dart` est un release candidate (`1.0.0-rc.3`), importe depuis Git et non publie sur pub.dev au moment de cette recherche.
- Le binding expose bien `CbfBuilder`, `CbfClient` et `CbfNode`, mais son demo Flutter et ses tests Dart n'exercent pas encore de synchronisation CBF. Les exemples first-party connus sont cote Kotlin/Swift.
- La recherche n'a trouve aucun exemple public Dart/Flutter de Thunderbiscuit utilisant CBF. Ses exemples publics CBF identifies sont Kotlin (`tatooine` et `godzilla-wallet`), et ses anciens projets Dart sont `bdk-flutter`/`bdk-flutter-app`, anterieurs a cette API.
- Le controle d'erreur est encore sommaire : les etats de degradation passent par `Warning` et l'unique variante `CbfException` connue est `NodeStoppedCbfException`. Bull doit mapper les avertissements et erreurs d'infrastructure dans sa propre famille de failures, sans exposer les types BDK a la presentation.
- Les limitations amont ouvertes et bloquantes a revalider au demarrage du spike sont : wallet neuf sans recovery couteux (`bdk-kyoto#162`), ajout dynamique de scripts (`#143`) et `prev_txouts` manquants (`#136`). Le spike doit les verifier contre creation, derivation d'adresse, PSBT, RBF et Payjoin.
- `bdk_dart` expose deja `Wallet.applyUnconfirmedTxs()`, `applyUnconfirmedTxsEvents()`, `applyEvictedTxs()` et `insertTxout()`. L'insertion locale d'un envoi propre est donc une piste concrete, pas une API hypothetique. Le spike doit verifier sa persistance et sa reconciliation lors d'une confirmation, eviction ou replacement RBF.

## Regressions par rapport a Electrum

| Capacite | Electrum actuel | CBF seul | Consequence produit dans Bull | Mitigation et cout |
|---|---|---|---|---|
| Reception non confirmee | L'historique Electrum inclut mempool et blocs. | Les filtres ne portent que sur les blocs mines. Une reception entrante non confirmee est inconnue jusqu'a confirmation. | Pas de transaction entrante `pending`, pas de solde pending entrant et pas de notification fiable avant confirmation. `WalletTransaction.status` est aujourd'hui binaire pending/confirmed. | Accepter le comportement et l'expliquer dans l'UI, ou interroger une API mempool pour les scripts concernes. Cette seconde option revele de nouveau ces scripts au serveur. |
| Solde | BDK remplit confirmed, trusted/untrusted pending apres le scan Electrum. | Le solde confirme est correct ; les entrees mempool ne sont pas observees. | Les buckets pending ne sont plus alimentes par le scan CBF. | Ne pas marquer un paiement recu comme "final" avant confirmation ; eventuellement enrichir seulement une demande de paiement active via API mempool. |
| Envoi propre non confirme | Apres le broadcast, Bull lance un sync BDK (`SendCubit.broadcastTransaction()`), qui obtient alors la transaction du mempool via Electrum. | CBF ne peut pas recuperer cette transaction du mempool. Le broadcast actuel ne l'insere pas explicitement dans le graphe BDK persiste. | Sans travail supplementaire, l'historique et les UTXO ne doivent pas promettre d'afficher l'envoi comme pending avant confirmation. | Ajouter et tester une ecriture locale non sensible de la transaction diffusee dans le wallet BDK, ou utiliser un suivi de transaction cible via Electrum/API mempool. |
| Confirmations et reorgs | Tip/hauteur du serveur. | Verification locale des headers et meme calcul de confirmation pour les blocs connus. | Pas de regression attendue pour une transaction confirmee. | Tests de reorg et de calcul de confirmations pendant le spike. |
| Estimation de frais | Deja fournie par l'API mempool, pas Electrum. | Kyoto fournit au mieux des approximations P2P. | Aucune regression, car Bull conserve `FeesDatasource`. | Continuer les endpoints `/api/v1/fees/precise` puis `/fees/recommended`. |
| Broadcast et retour de rejet | Electrum retourne txid ou erreur de validation. | `CbfClient.broadcast()` existe et peut emettre `TransactionRejectedWarning`, mais ce signal BIP61 est optionnel/rare et ne restitue pas de facon fiable la distinction Electrum `missingorspent`/`non-final`. | Risque concret pour les swaps : `swap_watcher.dart:974-987` interprete ces deux erreurs. | Conserver le broadcast Electrum. Tester aussi le fallback multi-serveurs, qui traite actuellement toute `Exception` comme transitoire. Ne pas utiliser le warning CBF comme preuve d'acceptation. |
| RBF/CPFP d'un tiers | Electrum ne donne deja pas une vision complete des remplacements. | Une reception remplacee dans le mempool est invisible. | L'utilisateur ne doit jamais traiter une entree non confirmee comme paiement definitif. | API mempool facultative : `/api/v1/tx/:txid/rbf`, replacements et CPFP. Cela ajoute confiance et fuite de metadonnees. |
| Confidentialite | Un serveur Electrum connait les scripts demandes. | Le P2P CBF ne divulgue pas le jeu de scripts au serveur de scan. | Gain principal de CBF sur l'historique confirme. | Configurer des pairs/Tor ; eviter de reconstituer un scan complet par API mempool. |

Une API mempool ne "corrige" donc pas CBF gratuitement. `GET /api/scripthash/:scripthash/txs` ou les WebSockets de suivi restaurent la mempool, mais revelent les scripts au meme type de tiers qu'Electrum. `POST /api/tx` restaure un retour de broadcast exploitable, mais confie cette validation au backend. Le choix recommande est hybride et minimal : CBF pour l'historique confirme, API mempool uniquement pour les fonctions qui en ont un besoin securitaire ou explicite (fees deja existants, retour de broadcast swaps, et eventuellement un paiement en attente suivi a la demande).

## Pairs, donnees locales et Tor

CBF a besoin de pairs Bitcoin annoncant le service compact filters. `CbfBuilder` permet de fournir des pairs IP, un nombre de connexions, des timeouts et un proxy SOCKS5. Le plan doit prevoir :

- une politique de bootstrap documentee, avec plusieurs pairs et rotation ;
- un repertoire CBF par reseau et par wallet, non partage entre mainnet/testnet ;
- une politique d'espace disque, de retention et de suppression atomique avec le wallet ;
- l'absence de secret dans ce repertoire ou dans les logs de progression ;
- une migration de stockage et une suppression verifiee lors de la suppression du wallet.

### Etat verifie de Tor+CBF (2026-07-22)

Faits verifies dans les sources upstream et le binding verrouille :

1. **Le bootstrap DNS de Kyoto n'est jamais proxifie.** `bip157` appelle `tokio::net::lookup_host` directement (`src/network/dns.rs:42-71`), dans toutes les versions publiees (0.3.4 a 0.6.3) et en master. La PR #566 le confirme par ecrit : la resolution de hostname reste locale meme avec un proxy SOCKS5 configure. C'est le meme pitfall que documente Bitcoin Core (`doc/tor.md` : DNS non proxyfie = requetes clearnet via le resolveur systeme).
2. **Une liste de pairs non vide ne suffit pas.** La whitelist est consommee une seule fois (`peer_map.rs:219-295`) ; si les pairs configures echouent ou se deconnectent (rotation ~2 h) et que le carnet d'adresses est vide, le bootstrap DNS clearnet se declenche automatiquement. Confirme par les mainteneurs dans la PR #586.
3. **Le correctif existe upstream mais pas dans notre pin.** `only_configured_peers()`/`whitelist_only` (bip157 v0.5.0, expose dans bdk-ffi par la PR #1047 mergee le 2026-07-13) empeche tout DNS et toute gossip. La revision bdk-ffi verrouillee par `bdk_dart` (`17c48b8b`) date d'avant cette PR ; le symbole n'existe pas dans `lib/bdk.dart`. Avec `whitelist_only`, l'epuisement de la liste arrete le noeud (`NoReachablePeers`) au lieu de reessayer : l'app devra gerer ce redemarrage.
4. **Les pairs onion existent en Rust mais pas dans le FFI.** `bip157` supporte les `.onion` v3 via SOCKS5 domain-CONNECT (PR #541), mais la structure `Peer` de bdk-ffi n'expose que `IpAddress` ; aucun pair onion/hostname n'est configurable depuis Dart. Pas de support SOCKS5 RESOLVE.
5. **Router les pairs clearnet via un exit Tor est une pratique standard** (Bitcoin Core `-proxy=127.0.0.1:9050`), et Bull possede deja toute l'infrastructure : toggle `useTorProxy` + `torProxyPort` (defaut 9050, table settings), proxy applique aux connexions Electrum Bitcoin (`electrum_servers_adapter.dart:58-60`), daemon Tor embarque (`package:tor` de Foundation Devices) et ecran de reglages Tor.
6. **Interaction produit obligatoire en V1 sans Tor** : si `useTorProxy` est actif, le trafic Electrum Bitcoin passe par Tor mais un noeud CBF V1 s'y soustrairait silencieusement. La V1 doit donc soit bloquer la selection CBF quand Tor est actif, soit exiger une confirmation explicite "la synchronisation privee n'utilise pas Tor pour l'instant". Un contournement silencieux est un downgrade de confidentialite inacceptable.

**Chemin Tor V1.x realiste** : bump du pin `bdk-ffi` dans `bull_sdk` vers une revision >= PR #1047, `onlyConfiguredPeers()` + liste IP auditee non vide + `socks5Proxy(127.0.0.1:torProxyPort)`, gestion du redemarrage sur `NoReachablePeers`, puis capture reseau prouvant zero DNS et zero connexion hors SOCKS5. Sans ce bump, Tor+CBF reste no-go car la fuite DNS est structurelle.

Les choix de pair et de repertoire restent des decisions de securite/confidentialite. Aucun pair par defaut, DNS seed ou chemin de stockage ne doit etre fige sans revue securite et test sur appareils reels.

## Limites precises sans mempool BDK

Conserver Electrum pour le broadcast ne reintroduit pas le mempool dans BDK. Le chemin actuel `BdkBitcoinBlockchainDatasource` diffuse seulement une transaction et retourne un txid ou une erreur. Ensuite `SendCubit.broadcastTransaction()` demande un sync wallet. C'est ce sync Electrum, et non le broadcast, qui alimente aujourd'hui `bdkWallet.transactions()`, `listUnspent()` et `balance()` avec les donnees mempool. Un wallet configure CBF ne doit donc pas compter sur Electrum broadcast pour actualiser ces donnees.

| Fonctionnalite actuelle | Ce qui depend du mempool BDK | Limitation avec CBF seul | Mitigation possible | Cout / decision |
|---|---|---|---|---|
| Reception Bitcoin 0-conf | Electrum ajoute la transaction entrante dans le graphe BDK pendant le full scan. | La transaction, son montant et son UTXO n'apparaissent qu'apres le premier bloc. Il n'y a pas de notification wallet fiable a 0-conf. | Accepter "en attente de confirmation" ; ou suivre uniquement l'adresse d'une demande de paiement active via Electrum/API mempool/WebSocket. | Le suivi adresse divulgue cette adresse a un serveur et reduit le gain de confidentialite CBF. |
| Solde pending | `BdkWalletDatasource.getBalance()` expose `trustedPendingSat` et `untrustedPendingSat` issus de `bdkWallet.balance()`. | Les buckets pending ne sont plus alimentes. Le solde confirme reste correct. | Afficher le solde confirme comme autorite ; ajouter optionnellement une annotation non spendable pour une demande de paiement suivie. | Ne jamais transformer une observation distante en solde spendable. |
| Historique `pending` | `BdkWalletDatasource.getTransactions()` transforme une position sans confirmation en `WalletTransactionStatus.pending`. | Les receptions 0-conf disparaissent de la liste ; l'UI, le detail et le CSV ne peuvent pas les montrer. | Meme suivi cible, dans un modele separe marque "observe par serveur" ; ou attendre confirmation. | Ne pas melanger une observation serveur et une transaction verifiee CBF sans l'indiquer. |
| UTXO / ecran Coins | `bdkWallet.listUnspent()` fournit les outputs connus et `confirmationsFromTip()` affiche 0 pour un output non confirme. | Un coin entrant 0-conf est inconnu, donc pas visible, gelable ou selectionnable. | Attendre confirmation est le comportement initial recommande. | Aucune perte de securite : un coin non connu ne peut pas etre depense par erreur. |
| Envoi propre juste diffuse | Le broadcast retourne un txid, puis le sync Electrum rend normalement la transaction visible a BDK. | L'ecran Send peut annoncer le succes grace au txid, mais l'historique/solde/Coins BDK ne doivent pas promettre un etat pending avant confirmation. | Apres broadcast Electrum reussi, appliquer `UnconfirmedTx` avec `Wallet.applyUnconfirmedTxs()` puis persister le wallet. Tester confirmation, eviction, replacement et redemarrage. | L'insertion locale est preferable pour la confidentialite, mais ne prouve pas que tous les peers ont conserve la transaction. Une observation distante reste necessaire pour connaitre une eviction avant confirmation. |
| RBF d'un envoi propre | Le flag RBF est local (`isExplicitlyRbf()`), mais la transaction doit etre presente dans `bdkWallet.transactions()` pour etre choisie depuis l'historique. | Sans insertion locale, le flux RBF peut ne pas etre accessible apres fermeture/reouverture avant confirmation. | Utiliser et tester `applyUnconfirmedTxs()` pour le parent et `applyEvictedTxs()`/les events wallet pour la reconciliation. | La parite RBF complete reste conditionnee a la detection fiable du replacement/eviction ; elle doit avoir son propre critere go/no-go. |
| CPFP | Un enfant doit depenser un output connu par le wallet ; la decouverte d'un output non confirme repose aujourd'hui sur le graphe BDK synchronise. | CPFP d'un changement non confirme peut etre indisponible apres reprise si l'envoi parent n'est pas localement persiste. | Meme insertion locale testee ; ne pas proposer CPFP tant que parent/change ne sont pas connus localement. | Ne jamais construire CPFP a partir d'une donnee serveur non verifiee sans les prevouts necessaires. |
| Coin selection / Payjoin | Payjoin et la selection consultent les UTXO BDK ; Payjoin ajoute aussi des inputs et prevouts etrangers. | Les nouveaux fonds 0-conf ne sont pas utilisables. L'issue `bdk-kyoto#136` signale que les `prev_txouts` etrangers sont une limite fondamentale potentielle pour Payjoin. | Exiger les UTXO propres confirmes ne suffit pas a conclure. Tracer et tester la verification des inputs/frais dans `pdk_payjoin_datasource.dart` avec un vrai Payjoin CBF. | Payjoin reste Electrum ou est desactive pour les wallets CBF si la verification de tous les prevouts ne peut pas etre prouvee. |
| Swaps on-chain | Les statuts de swap viennent principalement de Boltz ; `SwapWatcher` depend aussi des erreurs de broadcast Electrum. | L'absence de mempool BDK ne retire pas les retours `missingorspent`/`non-final` si le broadcast reste Electrum. Le lockup peut toutefois ne pas etre visible dans l'historique wallet avant confirmation. | Garder Electrum pour broadcast et continuer le suivi Boltz existant. | Pas de regression de securite swaps attendue sur ce chemin ; tester le decalage d'affichage wallet. |
| Frais reseau | Bull n'utilise pas le mempool BDK : `FeesDatasource` appelle deja le serveur mempool configure. | Aucune. | Conserver le flux actuel. | Aucun compromis CBF supplementaire. |

### Niveaux de mitigation recommandes

1. **V1 CBF, la plus privee et la plus simple** : historique, solde et UTXO uniquement confirmes ; Electrum uniquement pour broadcast et ses erreurs ; frais inchanges. Cela perd 0-conf, RBF/CPFP apres reprise tant qu'un envoi n'est pas confirme, et rend cette limite explicite a l'utilisateur.
2. **V1.1, parite pour les envois propres** : apres un broadcast Electrum reussi, utiliser `Wallet.applyUnconfirmedTxs()` et persister le wallet. Cela peut restaurer l'historique pending, RBF, CPFP et le change sans demander les adresses a un serveur. `applyEvictedTxs()` et les events BDK doivent reconciler eviction/replacement/confirmation. Cette insertion ne prouve pas que le mempool a conserve durablement la transaction.
3. **V1.2, receptions 0-conf opt-in** : suivi cible d'une adresse de facture active ou d'un txid via un serveur Electrum/mempool ou WebSocket. L'UI distingue alors "observe par le serveur, non confirme" de "confirme via CBF". Ne pas etendre ce mecanisme a tous les scripts du wallet.
4. **A eviter** : lancer un full scan Electrum periodique en plus de CBF. Cela restaure la parite mempool, mais revele regulierement l'ensemble des scripts et annule pratiquement le benefice de confidentialite qui justifie CBF.

## Sources primaires

Toutes les sources ont ete consultees le 2026-07-22 UTC.

- BIP157, "Client Side Block Filtering", statut Deployed : https://github.com/bitcoin/bips/blob/master/bip-0157.mediawiki
- BIP158, "Compact Block Filters for Light Clients", statut Deployed : https://github.com/bitcoin/bips/blob/master/bip-0158.mediawiki
- Book of BDK, "Compact Block Filters" : https://bookofbdk.com/design/cbf/
- Book of BDK, "CBF Sync with Kyoto" : https://bookofbdk.com/cookbook/syncing/kyoto/
- BDK Dart, README et source du binding : https://github.com/bitcoindevkit/bdk-dart
- BDK FFI, facade Kyoto : https://github.com/bitcoindevkit/bdk-ffi/blob/master/bdk-ffi/src/kyoto.rs
- BDK Kyoto : https://github.com/bitcoindevkit/bdk-kyoto
- BDK Kyoto #136, prev_txouts : https://github.com/bitcoindevkit/bdk-kyoto/issues/136
- BDK Kyoto #143, ajout dynamique de scripts : https://github.com/bitcoindevkit/bdk-kyoto/issues/143
- BDK Kyoto #162, recovery des wallets neufs : https://github.com/bitcoindevkit/bdk-kyoto/issues/162
- Kyoto, details de conception : https://github.com/2140-dev/kyoto/blob/master/DETAILS.md
- Kyoto, resolution DNS non proxifiee : https://github.com/2140-dev/kyoto/blob/master/src/network/dns.rs
- Kyoto PR #566, hostname resolu localement malgre SOCKS5 : https://github.com/2140-dev/kyoto/pull/566
- Kyoto PR #567, mode whitelist_only : https://github.com/2140-dev/kyoto/pull/567
- Kyoto PR #541, pairs onion v3 via SOCKS5 domain-CONNECT (Rust uniquement) : https://github.com/2140-dev/kyoto/pull/541
- Kyoto PR #586, epuisement de whitelist et retour DNS/gossip : https://github.com/2140-dev/kyoto/pull/586
- BDK FFI PR #1047, only_configured_peers (posterieure au pin bdk-dart) : https://github.com/bitcoindevkit/bdk-ffi/pull/1047
- Bitcoin Core, doc Tor et avertissement DNS : https://github.com/bitcoin/bitcoin/blob/master/doc/tor.md
- Android, long-running workers : https://developer.android.com/develop/background-work/background-tasks/persistent/how-to/long-running
- Android, foreground-service timeouts : https://developer.android.com/develop/background-work/services/fgs/timeout
- Apple, choix des strategies de fond : https://developer.apple.com/documentation/backgroundtasks/choosing-background-strategies-for-your-app
- Apple, long-running tasks iOS/iPadOS : https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados
- mempool backend, routes API : https://github.com/mempool/mempool/blob/master/backend/src/api/bitcoin/bitcoin.routes.ts
