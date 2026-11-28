import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:overview/overview.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show WalletSigner;
import 'package:silent/silent.dart';
import 'package:swap_feature/swap_feature.dart'
    show SwapActivity, SwapHomeServerCheck;
import 'package:swaps/swaps.dart' show Swap;
import 'package:sync/sync.dart' show WalletKey;

/// Settles the chained microtasks of a controller without a widget pump.
Future<void> flushEvents([int turns = 12]) async {
  for (var i = 0; i < turns; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class MockSwapActivity extends Mock implements SwapActivity {}

final class FakeOverviewSource implements OverviewHomeSource {
  final _changes = StreamController<void>.broadcast();
  void Function()? onPublish;
  OverviewHomeSnapshot _snapshot = (
    status: OverviewCatalogueStatus.replacing,
    wallets: const <OverviewHomeWallet>[],
  );

  int snapshots = 0;

  @override
  Stream<void> get changes => _changes.stream;

  @override
  OverviewHomeSnapshot get snapshot {
    snapshots++;
    return _snapshot;
  }

  void publish(OverviewHomeSnapshot snapshot) {
    _snapshot = snapshot;
    onPublish?.call();
    _changes.add(null);
  }

  Future<void> close() => _changes.close();
}

const OverviewHomeSnapshot emptySnapshot = (
  status: OverviewCatalogueStatus.empty,
  wallets: <OverviewHomeWallet>[],
);

OverviewHomeSnapshot snapshot(
  OverviewCatalogueStatus status,
  List<OverviewHomeWallet> wallets,
) => (status: status, wallets: wallets);

OverviewHomeWallet homeWallet(
  String id, {
  Network network = BitcoinNetwork.regtest,
  String? label,
  bool isDefault = false,
  WalletSigner signer = WalletSigner.local,
  int? balanceSat = 0,
  Fingerprint? masterFingerprint,
}) => (
  entry: (
    key: WalletKey(id: id, network: network),
    script: ScriptType.bip84,
    signer: signer,
    label: label,
    isDefault: isDefault,
    masterFingerprint: masterFingerprint,
  ),
  balanceSat: balanceSat,
);

final class FakeHomeSync implements HomeSyncPass {
  final _activity = StreamController<bool>.broadcast();
  final _pending = <Completer<HomeSyncOutcome>>[];
  final triggers = <SyncTrigger>[];

  /// When false, [sync] stays pending until [completeNext] is called.
  bool autoComplete = true;
  HomeSyncOutcome outcome = HomeSyncOutcome.completed;
  bool active = false;

  int get pending => _pending.length;

  @override
  bool get isSyncPassActive => active;

  @override
  Stream<bool> get activity => _activity.stream;

  @override
  Future<HomeSyncOutcome> sync({required SyncTrigger trigger}) {
    triggers.add(trigger);
    if (autoComplete) return Future.value(outcome);
    final completer = Completer<HomeSyncOutcome>();
    _pending.add(completer);
    return completer.future;
  }

  void completeNext(HomeSyncOutcome value) =>
      _pending.removeAt(0).complete(value);

  void completeAt(int index, HomeSyncOutcome value) =>
      _pending.removeAt(index).complete(value);

  void setActive(bool value) {
    active = value;
    _activity.add(value);
  }

  Future<void> close() => _activity.close();
}

final class FakeAmountDisplayPreferences
    implements AmountDisplayPreferencesReader {
  final _stream =
      StreamController<
        Result<AmountDisplayPreferences, PreferencesFailure>
      >.broadcast();

  @override
  Stream<Result<AmountDisplayPreferences, PreferencesFailure>>
  watchDisplayPreferences() => _stream.stream;

  void publish(AmountDisplayPreferences preferences) =>
      _stream.add(Ok(preferences));

  void fail(PreferencesFailure failure) => _stream.add(Err(failure));

  Future<void> close() => _stream.close();
}

final class FakeOngoingSwaps implements OngoingSwaps {
  Result<List<Swap>, OngoingSwapsFailure> result = const Ok([]);
  bool manual = false;
  int reads = 0;
  final _pending = <Completer<Result<List<Swap>, OngoingSwapsFailure>>>[];

  @override
  Future<Result<List<Swap>, OngoingSwapsFailure>> read() {
    reads++;
    if (!manual) return Future.value(result);
    final completer = Completer<Result<List<Swap>, OngoingSwapsFailure>>();
    _pending.add(completer);
    return completer.future;
  }

  void complete(Result<List<Swap>, OngoingSwapsFailure> value) =>
      _pending.removeAt(0).complete(value);
}

final class FakeSwapServerCheck implements SwapHomeServerCheck {
  bool isReachable = true;
  bool manual = false;
  int checks = 0;
  final pending = <Completer<bool>>[];

  @override
  Future<bool> reachable() {
    checks++;
    if (!manual) return Future.value(isReachable);
    final result = Completer<bool>();
    pending.add(result);
    return result.future;
  }
}

final class FakeSilent extends Fake implements Silent {
  bool enabled = false;
  bool setUp = false;
  SilentWallet? wallet;
  int refreshes = 0;

  @override
  Future<Result<bool, SilentFailure>> isFeatureEnabled() async => Ok(enabled);

  @override
  Future<Result<bool, SilentFailure>> isSetUp() async => Ok(setUp);

  @override
  bool get isScanning => false;

  @override
  Future<Result<SilentWallet?, SilentFailure>> refresh() async {
    refreshes++;
    return Ok(wallet);
  }

  @override
  Stream<Result<SilentUpdate, SilentFailure>> watchUpdates() =>
      const Stream.empty();
}

SilentWallet silentWallet(
  int balanceSat, {
  BitcoinNetwork network = BitcoinNetwork.regtest,
}) => SilentWallet(
  network: network,
  spAddress: 'sp1qexample',
  balance: SilentBalance(
    confirmedSat: Sats.fromInt(balanceSat),
    totalUnifiedSat: Sats.fromInt(balanceSat),
  ),
  isScanning: false,
);

/// One controller wired to fakes only: no native wallet, no descriptor and no
/// Secrets or Sync session is needed to exercise Home.
final class OverviewHomeHarness {
  final source = FakeOverviewSource();
  final sync = FakeHomeSync();
  final amountPreferences = FakeAmountDisplayPreferences();
  final swaps = FakeOngoingSwaps();
  final swapServer = FakeSwapServerCheck();
  final silent = FakeSilent();
  final started = StreamController<HomeSyncStart>.broadcast();
  final finished = StreamController<WalletKey>.broadcast();
  final electrum = StreamController<HomeElectrumOutcome>.broadcast();
  final swapActivity = MockSwapActivity();

  final backupReads = <Completer<bool?>>[];
  bool manualBackups = false;
  bool? backupAnswer = true;
  final physicalBackups = <String, bool>{};
  bool proxyNeedsAttention = false;
  bool manualProxy = false;
  final proxyReads = <Completer<bool>>[];
  int backupReadsStarted = 0;

  late final OverviewHomeController controller = OverviewHomeController(
    catalogue: source,
    sync: sync,
    amountDisplay: OverviewAmountDisplay(amountPreferences),
    ongoingSwaps: swaps,
    swapServerCheck: swapServer,
    readBackupWarning: () {
      backupReadsStarted++;
      if (!manualBackups) return Future.value(backupAnswer);
      final completer = Completer<bool?>();
      backupReads.add(completer);
      return completer.future;
    },
    readPhysicalBackup: (key) async => physicalBackups[key.id] ?? false,
    proxyNeedsAttention: () {
      if (!manualProxy) return Future.value(proxyNeedsAttention);
      final completer = Completer<bool>();
      proxyReads.add(completer);
      return completer.future;
    },
    silentHome: SilentHomeObservation(silent),
    syncStarted: started.stream,
    syncFinished: finished.stream,
    electrumResults: electrum.stream,
    swapActivity: swapActivity,
  );

  OverviewHomeHarness() {
    source.onPublish = () {
      if (controller.isClosed) throw StateError('Controller is closed');
    };
    registerFallbackValue(SyncTrigger.automatic);
    when(() => swapActivity.retryOngoingSwaps()).thenAnswer((_) async {});
  }

  void emitElectrum(
    WalletKey key, {
    required bool isLiquid,
    required bool success,
    int runId = 1,
  }) {
    started.add((key: key, runId: runId));
    electrum.add((
      key: key,
      runId: runId,
      isLiquid: isLiquid,
      success: success,
    ));
  }

  /// Builds the controller and lets its initial reads settle. Call it after
  /// configuring the fakes, so the first reads observe that configuration.
  Future<void> mount() async {
    if (controller.isClosed) throw StateError('controller already closed');
    await flushEvents();
  }

  Future<void> close() async {
    await controller.close();
    await source.close();
    await started.close();
    await finished.close();
    await electrum.close();
    await amountPreferences.close();
    await sync.close();
  }
}
