# Design technique CBF : problemes, solutions et snippets

Ce document detaille l'implementation proposee sans modifier le code applicatif. Il accompagne `compact-block-filters-feasibility.md` et `compact-block-filters-implementation-plan.md`.

## Legende des snippets

- Les snippets **API BDK verifiee** correspondent a `bdk_dart 1.0.0-rc.3`, verrouille dans `pubspec.lock`.
- Les snippets **pseudo-code Bull** definissent les limites et le flux souhaites. Ils ne sont pas des fichiers a copier tels quels : les noms definitifs doivent suivre les interfaces deja presentes et le spike doit d'abord valider le comportement natif.
- Aucun type `bdk_*` ne doit traverser la frontiere data -> domain -> presentation.

## 1. Choix CBF par wallet

### Probleme et pourquoi

CBF et Electrum n'ont pas les memes proprietes : CBF protege la recherche de l'historique confirme mais ne voit pas le mempool. Un switch global et implicite modifierait des wallets existants sans consentement et rendrait les regressions 0-conf difficiles a expliquer. Le wizard s'execute avant la creation du wallet, alors que le backend doit etre determine par wallet et doit aussi couvrir les imports et recoveries.

### Resolution conceptuelle

Persister un `BitcoinSyncBackend` dans les structures existantes `WalletMetadatas` et `WalletMetadataModel`. Les wallets existants migrent explicitement vers `electrum`; seuls les nouveaux wallets peuvent choisir CBF. Le wizard pre-locator ajoute une valeur a `WizardChoices`, puis `ApplyPendingWizardChoicesUsecase` la transfere vers `SettingsRepository`. `CreateDefaultWalletsUsecase` consomme ce defaut global, comme il consomme aujourd'hui `environment`, mais le backend effectivement persiste reste par wallet.

### Pseudo-code Bull

```dart
enum BitcoinSyncBackend { electrum, compactBlockFilters }

// Field added to the existing WalletMetadataModel and WalletMetadatas table.
final BitcoinSyncBackend bitcoinSyncBackend;

class CreateDefaultWalletsUsecase {
  Future<void> execute({
    BitcoinSyncBackend bitcoinSyncBackend = BitcoinSyncBackend.electrum,
  }) {
    // Persist this only for the newly-created Bitcoin wallet.
    // Liquid remains on LWK/Electrum.
  }
}
```

La migration Drift 13 -> 14 ajoute une colonne non nulle avec valeur par defaut `electrum`, met a jour les mappers et regenere les snapshots avec `make drift-migrations`. Le changement de backend apres creation est une fonctionnalite distincte : il doit expliquer la perte des observations mempool, initialiser le stockage CBF sans toucher au wallet BDK, et ne jamais supprimer les donnees Electrum/CBF sans confirmation.

## 2. Frontiere de synchronisation et etats de progression

### Probleme et pourquoi

`SyncWalletUsecase` et `SyncCoordinator` modelisent une operation courte `Future<void>`. CBF est un processus long avec connexion de pairs, progression de filtres, avertissements recuperables et annulation. Faire passer `bdk.Info` ou un `CbfClient` au BLoC casserait les frontieres data/domain et rendrait la presentation dependante de la FFI.

### Resolution conceptuelle

Ajouter un contrat domaine de progression, avec un seul flux actif par wallet. Electrum et Liquid le traduisent en progression indeterminee, ce qui permet de reutiliser la meme UI sans pretendre produire un pourcentage. La datasource est l'unique proprietaire du client CBF et mappe `Info`/`Warning` en types Bull.

### Pseudo-code Bull

```dart
sealed class WalletSyncProgress {
  const WalletSyncProgress();
}

class SyncConnecting extends WalletSyncProgress {
  const SyncConnecting();
}

class SyncScanning extends WalletSyncProgress {
  final double filtersDownloadedPercent;
  final int chainHeight;

  const SyncScanning({
    required this.filtersDownloadedPercent,
    required this.chainHeight,
  });
}

class SyncDegraded extends WalletSyncProgress {
  final WalletSyncWarning warning;

  const SyncDegraded(this.warning);
}

class SyncCompleted extends WalletSyncProgress {
  const SyncCompleted();
}

class SyncCancelled extends WalletSyncProgress {
  const SyncCancelled();
}

abstract interface class WalletSyncRepository {
  Stream<Result<WalletSyncProgress, WalletSyncFailure>> sync(Wallet wallet);
  Future<void> cancel(String walletId);
}
```

Le contrat final est additif : interface `WalletSyncRepository` dans `domain/repositories/`, implementation dans `data/`, et famille `WalletSyncFailure` scellee. Il ne migre pas le reste de `core/wallet`, encore fonde sur `BullException`, dans la meme PR. Le repository actuel est une dette legacy concrete ; son refactoring global est facultatif et reste un commit atomique distinct.

## 3. Cycle de vie CBF, pairs et persistence

### Probleme et pourquoi

Un client CBF doit telecharger une chaine de headers/filtres et entretenir des pairs P2P. Son `dataDir` persiste separerement du persister SQLite du wallet BDK. Deux demarrages pour le meme wallet peuvent gaspiller la bande passante ou corrompre l'etat. Un chemin partage entre reseaux peut melanger les donnees.

### Resolution conceptuelle

Creer `CbfWalletDatasource`, proprietaire d'un registre de sessions actif indexe par wallet. Une session comprend le client, le noeud et les abonnements de lecture. Son repertoire est construit a partir du wallet id et du reseau, sous le stockage applicatif. La V1 injecte une politique de bootstrap clearnet et n'utilise pas `socks5Proxy`. Fait verifie : le DNS de Kyoto n'est jamais proxifie (toutes versions), la whitelist est consommee une seule fois et le DNS clearnet se re-declenche quand les pairs configures echouent ; le mode `only_configured_peers` qui corrige cela est arrive dans bdk-ffi apres le pin actuel de `bdk_dart` et `Peer` n'expose ni hostname ni onion au FFI. Une integration Tor exige donc d'abord un bump de pin (porte GT du plan).

### API BDK verifiee

```dart
final components = CbfBuilder()
    .peers(peers)
    .connections(2)
    .dataDir(cbfDataDir)
    .scanType(scanType)
    .build(wallet: bdkWallet);

components.node.run();

final info = await components.client.nextInfo();
final warning = await components.client.nextWarning();
final update = await components.client.update();
bdkWallet.applyUpdate(update: update);

components.client.shutdown();
```

`nextInfo()`, `nextWarning()` et `update()` sont des attentes independantes. Il faut lancer des lecteurs concurrents et les annuler/ignorer proprement quand la session est arretee ; attendre sequentiellement ces trois appels bloquerait la progression ou les warnings.

### Pseudo-code Bull

```dart
class CbfWalletDatasource {
  final Map<String, _CbfSession> _sessions = {};

  Stream<WalletSyncProgress> sync(WalletModel wallet) {
    final session = _sessions.putIfAbsent(
      wallet.id,
      () => _CbfSession.start(wallet, _dataDirFor(wallet)),
    );
    return session.progress;
  }

  Future<void> cancel(String walletId) async {
    final session = _sessions.remove(walletId);
    if (session == null) return;
    try {
      await session.shutdown();
    } on bdk.NodeStoppedCbfException {
      // Bull's wrapper is idempotent although native shutdown is not.
    }
  }
}
```

Le shutdown Bull doit etre idempotent et protege contre deux annulations concurrentes ; un simple `Map.remove()` ne suffit pas si une autre voie de lifecycle detient deja la session. Toute autre exception est capturee ici, journalisee sans id de wallet, descripteur, adresse, pair ou secret, puis traduite en `WalletSyncFailure`.

## 4. Premier scan, recovery et derivation de nouvelles adresses

### Probleme et pourquoi

Pour restaurer un wallet, le scan peut couvrir un historique important. L'API Dart expose `SyncScanType` et `RecoveryScanType`; le mauvais choix peut provoquer un scan depuis trop loin ou manquer des fonds. Une limitation upstream concerne aussi l'ajout de scripts apres le demarrage : reveler une nouvelle adresse pendant une session CBF ne doit pas etre suppose automatiquement observe.

### Resolution conceptuelle

Pour un wallet existant synchronise, utiliser `SyncScanType()`. Pour une restauration, construire `RecoveryScanType` avec un index utilise et un `RecoveryPoint` valide. Le `birthday` actuel est un `DateTime?` de `WalletMetadataModel`, alors que `OtherRecoveryPoint` exige un `BlockId` hauteur+hash : la conversion necessite une source de checkpoint et une decision de confidentialite explicites. Pour chaque nouvelle adresse revelee, finir proprement la session courante ; l'ajout dynamique reste bloque tant que `bdk-kyoto#143` n'est pas exclu par le spike.

### Pseudo-code Bull

```dart
bdk.ScanType scanTypeFor(WalletMetadataModel metadata, {required bool isRecovery}) {
  if (!isRecovery) return bdk.SyncScanType();

  return bdk.RecoveryScanType(
    usedScriptIndex: verifiedUsedScriptIndex(metadata),
    checkpoint: checkpointFromVerifiedBlockId(metadata.birthday),
  );
}

Future<AddressInfo> revealAddress(...) async {
  final address = await walletDatasource.getNewAddress(...);
  await syncDatasource.cancel(walletId);
  // A later resume creates a session from the newly persisted wallet scripts.
  return address;
}
```

Les classes BDK sont exactes ; `verifiedUsedScriptIndex` et `checkpointFromVerifiedBlockId` sont volontairement des placeholders. Le premier doit couvrir correctement les keychains externe/interne ; le second ne peut pas convertir un timestamp sans obtenir et verifier une hauteur et un hash de bloc.

## 5. UI de progression et annulation

### Probleme et pourquoi

L'indicateur actuel est binaire et indetermine. Un download de filtres peut etre long : sans explication, l'utilisateur peut fermer l'app, creer un second sync ou croire que son wallet est bloque. Les warnings CBF (`NeedConnections`, timeout, tip potentiellement stale, pair sans compact filters) sont des etats recuperables, pas necessairement des erreurs fatales.

### Resolution conceptuelle

Le BLoC/Cubit observe le use case et convertit le type domaine en etat presentation. Aucun composant determine n'existe actuellement : un nouveau composant reutilisable doit etre cree dans `bull_ui`, tandis que `BullSyncButton` conserve le role d'action. La page affiche connexion, pourcentage, hauteur, avertissement recuperable, bouton annuler et reprise. Une annulation est neutre, pas une erreur localisee rouge.

### Pseudo-code Bull

```dart
class WalletSyncCubit extends Cubit<WalletSyncState> {
  final SyncWalletWithProgressUsecase _syncWallet;
  final CancelWalletSyncUsecase _cancelWalletSync;

  Future<void> start(Wallet wallet) async {
    await emit.forEach(
      _syncWallet.execute(wallet),
      onData: (result) => result.fold(
        (progress) => WalletSyncState.fromProgress(progress),
        (failure) => WalletSyncState.failure(failure),
      ),
    );
  }

  Future<void> cancel(String walletId) => _cancelWalletSync.execute(walletId);
}
```

La UI ne recalcule ni les pourcentages ni les decisions de reprise. Les textes sont des cles de localisation, et aucun libelle de warning natif BDK n'est montre tel quel.

## 6. Background, interruption et reprise

### Probleme et pourquoi

`CbfNode.run()` cree un thread dans le processus. Android et iOS peuvent suspendre ou tuer ce processus ; WorkManager/BGTask ne garantissent ni un temps suffisant ni une progression observable. Utiliser la tache periodique actuelle comme un scan sans limite peut epuiser batterie et budget OS.

### Resolution conceptuelle

Version initiale : scan strictement foreground avec persistence. A toute sortie de `AppLifecycleState.resumed`, demander et attendre autant que l'OS le permet l'arret du client, puis reprendre depuis `dataDir` au prochain foreground. Aucun CBF n'est ajoute au handler WorkManager/BGTask en V1. Un foreground service Android, `BGProcessingTask` ou `BGContinuedProcessingTask` iOS sont des projets plateformes separes apres le lancement initial.

Un futur background ne pourra pas se contenter de `Future.timeout()`, qui n'arrete pas le thread Tokio. Sa PR devra prouver sur appareil que `shutdown()` termine avant destruction de l'isolate et que l'application reste correcte si iOS ne lance jamais la tache.

## 7. Transactions 0-conf, UTXO et solde pending

### Probleme et pourquoi

CBF ne transmet pas le mempool. Bull derive actuellement l'historique de `bdkWallet.transactions()`, les UTXO de `listUnspent()` et les balances pending de `balance()` apres un scan Electrum. Avec CBF seul, une reception 0-conf et ses UTXO n'existent pas dans le graphe BDK local. L'envoi propre est aussi concerne : `SendCubit.broadcastTransaction()` diffuse puis appelle un sync, sans ajouter explicitement la transaction au wallet BDK persiste.

### Resolution conceptuelle

Definir le comportement produit initial : CBF affiche avec autorite les fonds confirmes uniquement. Ne pas fabriquer un solde pending depuis une heuristique. Pour les envois propres, le binding fournit deja `applyUnconfirmedTxs()`/`applyUnconfirmedTxsEvents()` et `applyEvictedTxs()` ; le spike doit valider persistance, change, RBF/CPFP et reconciliation. Une API mempool n'est necessaire que si le produit veut restaurer une observation distante 0-conf ; elle ne doit jamais servir de scan complet sous peine de perdre le gain de confidentialite CBF.

### Pseudo-code Bull

```dart
// Le mapping reste honnete : pas de transaction BDK locale == pas de pending.
WalletTransactionStatus statusFor(ChainPosition position) =>
    position.isConfirmed
        ? WalletTransactionStatus.confirmed
        : WalletTransactionStatus.pending;

Future<void> afterBitcoinBroadcast(SignedTransaction transaction) async {
  await electrumBroadcaster.broadcast(transaction);
  bdkWallet.applyUnconfirmedTxs(
    unconfirmedTxs: [
      bdk.UnconfirmedTx(tx: transaction.bdkTransaction, lastSeen: nowEpoch),
    ],
  );
  await persistWallet(bdkWallet);
}
```

Le snippet utilise les appels reels BDK mais les adaptateurs `transaction.bdkTransaction`, `nowEpoch` et `persistWallet` sont conceptuels. Le succes de broadcast autorise l'insertion locale ; il ne prouve pas la retention durable dans les mempools distants. L'UI doit pouvoir distinguer transaction locale non confirmee, observation distante eventuelle et confirmation CBF.

## 8. Broadcast Electrum et workflows sensibles

### Probleme et pourquoi

`CbfClient.broadcast()` et `TransactionRejectedWarning` existent, mais ce dernier repose sur BIP61, desactive chez la plupart des peers, et son `RejectReason` ne remplace pas les messages Electrum `missingorspent` et `non-final`. Bull depend de cette distinction dans `SwapWatcher`; changer ce comportement peut bloquer ou fausser une recuperation de swap.

### Resolution conceptuelle

Decoupler explicitement `WalletSyncBackend` de `BitcoinBroadcastBackend`. Dans la premiere version CBF, le backend de broadcast reste Electrum. Le fallback existant considere par defaut toute `Exception` comme transitoire ; les tests doivent donc verifier qu'un rejet permanent du premier serveur n'est pas masque par un second. Une future implementation Esplora/mempool est possible, mais doit satisfaire exactement les tests de rejection swaps avant activation.

### Pseudo-code Bull

```dart
abstract interface class BitcoinBroadcaster {
  Future<String> broadcastPsbt(String finalizedPsbt);
  Future<String> broadcastTransaction(Uint8List transaction);
}

class ElectrumBitcoinBroadcaster implements BitcoinBroadcaster {
  // Reuses BdkBitcoinBlockchainDatasource and ElectrumServersPort fallback.
}

class SyncWalletUsecase {
  // Chooses CBF or Electrum only for wallet synchronization.
}
```

Cette separation empeche une configuration CBF de changer par accident le chemin de broadcast.

## 9. RBF, coin selection et Payjoin

### Probleme et pourquoi

Le marquage RBF est local (`transaction.isExplicitlyRbf()`), mais le flux RBF commence generalement depuis une transaction que BDK connait. Si un envoi non confirme n'est pas dans `bdkWallet.transactions()`, il ne sera pas disponible dans l'historique pour lancer RBF. De meme, `listUnspent()` alimente coins et Payjoin : les coins entrants 0-conf ne sont pas decouverts sous CBF.

### Resolution conceptuelle

Premiere version : enregistrer localement l'envoi avec `applyUnconfirmedTxs()` seulement apres broadcast Electrum reussi, puis verifier que BDK applique les bonnes regles de confiance et de spendability. Ne pas inclure de coin entrant 0-conf inconnu dans la selection. Payjoin exige un test specifique des prevouts etrangers contre `bdk-kyoto#136`; des coins propres confirmes ne suffisent pas a garantir la verification du Payjoin.

### Pseudo-code Bull

```dart
bool canOfferRbf(WalletTransaction transaction) {
  return transaction.isPending && transaction.isRbf;
}

// Avec CBF, cette liste est naturellement limitee aux transactions que le
// graphe BDK connait. Aucun appel reseau de mempool n'est requis pour calculer
// isRbf ; il faut seulement que la transaction soit deja connue localement.
```

Tests obligatoires : envoi CBF, redemarrage, RBF/replacement avant confirmation, eviction, confirmation, CPFP du change, Payjoin avec prevouts etrangers, et verification que les coins pending ne deviennent jamais spendables par erreur.

## 10. Decoupage en branches et commits atomiques

Chaque item ci-dessous est une branche et un commit/PR autonome. Une branche dependante est ouverte depuis la precedente approuvee, jamais avec des milliers de lignes de migration melees a la FFI, au wizard ou a l'UI. Les commits ne doivent etre crees qu'apres validation des tests de leur propre perimetre.

| Ordre | Scope atomique | Inclut | Exclut expressement | Verification |
|---|---|---|---|---|
| 0 | Documentation et decision | Les trois documents CBF, sources, limites et go/no-go. | Code Dart, schema, dependances. | `git diff --check`. |
| 1 | Spike CBF testnet non produit | Harness/integration test CBF, rapport pass/fail, pairs clearnet, confidentialite des scripts, `applyUnconfirmedTxs`, Payjoin et lifecycle. | Migration, wizard, Tor, activation production. | Criteres chiffres de la Phase 0 sur Android/iOS reels. Go/no-go securite. |
| 2 | Configuration wallet et migration | Enum domaine `BitcoinSyncBackend`, colonne dans `WalletMetadatas`, champ `WalletMetadataModel`, migration 13 -> 14, snapshots et tests de migration. | Aucun appel CBF, aucune UI/wizard, aucun changement de sync. | `make drift-migrations`, tests historiques, `make analyze`, `make unit-test`. |
| 3 | Frontiere de sync additive | Nouveau `WalletSyncRepository` et implementation Electrum au comportement identique ; famille de failure limitee a la sync. | Refactoring global de `WalletRepository`, CBF, schema supplementaire, UX. | Tests repository/usecase ; comportement Electrum identique. |
| 4 | Backend CBF minimal derriere flag developpeur | `CbfWalletDatasource`, choix backend dans le repository, dataDir, session unique, persistence wallet, erreurs domaine et tests. | Wizard, progression utilisateur, background, modification broadcast. | Tests datasource/repository et integration testnet. Electrum reste le defaut. |
| 5 | Progression et UI kit | Etat de progression domaine/presentation, nouveau composant determine `bull_ui`, ecran de progression et annulation. | Changement de schema, choix wizard, background. | Tests BLoC/UI, l10n, petit ecran. |
| 6 | Wizard et creation par defaut | `WizardChoices`/`WizardField`, preference `SettingsRepository`, consommation par `CreateDefaultWalletsUsecase`, textes 0-conf. | Imports, recovery, modification moteur, migration. | Tests wizard/settings/onboarding ; Liquid inchange. |
| 7a | Import mnemonic | Choix CBF et passage au use case du feature. | Autres imports/recoveries. | Tests du feature. |
| 7b | Import watch-only | Descriptor/xpub CBF et recovery approprie. | Hardware/QR/recoveries. | Tests descriptor/xpub. |
| 7c | Hardware et QR | Choix CBF dans les imports approuves. | Mnemonic/watch-only/recoveries. | Tests par feature touche. |
| 7d | Recoveries et backup-test | Checkpoint/recovery CBF selon le resultat du spike. | Autres imports. | Tests de fonds retrouves vs controle Electrum. |
| 8 | Envois propres et RBF/CPFP | `applyUnconfirmedTxs`, persistance, events/eviction et tests RBF/CPFP. | Reception 0-conf globale, API mempool de suivi. | Envoi, restart, eviction, replacement, CPFP, confirmation. |
| 9 | Securite broadcast et Payjoin | Tests multi-serveurs des rejets Electrum ; validation Payjoin `#136`; extraction du contrat seulement si utile. | Bascule Esplora/mempool/P2P. | `missingorspent`, `non-final`, prevouts Payjoin, Send, swaps. |
| 10a | Background Android futur | Foreground service/notification et arret natif prouve. | iOS, lancement V1. | Appareils reels, Doze, kill, timeout, consommation. |
| 10b | Background iOS futur | Strategie iOS supportee et fallback si la tache ne s'execute jamais. | Android, lancement V1. | Appareils reels, expiration, kill, absence d'execution. |
| 10c | Tor futur (porte GT) | Bump pin `bdk-ffi` >= PR #1047 dans `bull_sdk`, `onlyConfiguredPeers()`, liste IP auditee, `socks5Proxy`, redemarrage sur `NoReachablePeers`. | Lancement V1, background, pairs onion (non exposes au FFI). | Capture reseau : zero DNS/connexion clearnet ; test d'epuisement de whitelist. |
| 11 | Beta et observabilite | Feature flag beta, metriques non sensibles, documentation support et rollback. | Migration automatique de wallets, collecte de secrets/metadonnees wallet. | Revue securite et validation release. |

Apres le go du spike, les scopes 2 a 6 forment la chaine minimale de lancement. Les imports 7a-7d ne sont ajoutes qu'aux parcours produit approuves. Le scope 9 peut se limiter aux tests de securite sans extraction si le broadcast Electrum actuel suffit. Les scopes 10a/10b/10c sont explicitement hors V1. Chaque commit respecte le format conventionnel du depot, par exemple `feat(wallet): persist bitcoin sync backend`, puis `feat(wallet): add compact filter sync backend`. Les titres et descriptions de PR sont maintenus dans `docs/compact-block-filters-pr-roadmap.md`.

## 11. Strategie de tests et criteres go/no-go

### Probleme et pourquoi

La FFI, les pairs P2P, le stockage persistant et les restrictions mobiles ne sont pas suffisamment couverts par les tests Dart de `bdk_dart`. Un test unitaire pur ne peut pas prouver un vrai sync CBF ni une reprise apres interruption.

### Resolution conceptuelle

Ajouter trois niveaux de tests, tous sur testnet avant beta : mapping unitaire, integration avec un vrai pair CBF, puis tests manuels instrumentes sur Android/iOS. Les tests n'utilisent jamais de seed de production ni n'enregistrent descripteurs/adresses dans les logs CI.

### Pseudo-code Bull

```dart
test('CBF progress maps BDK progress without leaking a peer address', () {
  final state = mapInfo(const BdkProgress(
    chainHeight: 100,
    filtersDownloadedPercent: 42.5,
  ));

  expect(state, isA<SyncScanning>());
  expect((state as SyncScanning).filtersDownloadedPercent, 42.5);
});

test('concurrent cancellation shuts down one active CBF session', () async {
  await datasource.sync(wallet).first;
  await Future.wait([
    datasource.cancel(wallet.id),
    datasource.cancel(wallet.id),
  ]);
  verify(() => fakeSession.shutdown()).called(1);
});
```

Le type `BdkProgress` ci-dessus est un fake de test, pas un type public BDK. Les criteres go/no-go complets et chiffres vivent en Phase 0 du plan principal : aucun script divulgue pendant le scan, zero corruption/lock/crash sur les cycles imposes, reconciliation des envois locaux, Payjoin prouve ou exclu, et parite des transactions confirmees avec un wallet de controle Electrum. Tor possede sa propre porte future.
