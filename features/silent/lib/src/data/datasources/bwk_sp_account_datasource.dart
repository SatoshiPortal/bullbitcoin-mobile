import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart'
    show Secret, SecretExtension, SecretFailure;
import 'package:silent/src/data/sp_storage_names.dart';
import 'package:silent/src/domain/sp_config.dart';
import 'package:rust_bindings/bwk.dart';

/// The bwk Silent Payments FFI: one live `SpAccount` and the simulations pinned
/// to it.
///
/// Speaks FFI view types only and throws whatever the boundary throws; the
/// repository maps both to domain types and typed failures.
class BwkSpAccountDatasource {
  SpAccount? _account;

  // The Blindbit server this session was opened against. The live account
  // cannot report it back, and the chain tip is read over HTTP rather than
  // through the account's electrum cursor.
  String? _blindbitUrl;

  // Confirmed FFI simulations pinned for the live session, keyed by draft id.
  // The simulation must round-trip UNCHANGED from preparePsbt into finalize, so
  // it stays here (never crosses the domain boundary) and is cleared on
  // dispose.
  final Map<String, TxSimulation> _simulations = {};
  int _nextDraftId = 0;

  bool get hasSession => _account != null;

  /// Async because the bwk-dart constructor is not `#[frb(sync)]`: FRB runs it
  /// on a worker isolate so the key derivation, the sqlite open and the header
  /// store open do not freeze the UI isolate.
  ///
  /// The account is opened by `package:secrets`, which hands the BIP39 seed to bwk
  /// itself: this layer never holds them. The repository maps custody failures
  /// to fixed text without logging or surfacing foreign error details.
  Future<Result<void, SecretFailure>> createFromSecret({
    required SpNetwork network,
    required Secret secret,
    required String blindbitUrl,
    required String electrumUrl,
    required String dataDir,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
    int minScanAmountSat = SpConfig.defaultMinScanAmountSat,
    required SpHeaderCheckpoint? headerCheckpoint,
  }) async {
    switch (await secret.silentPayments.account(
      name: SpStorageNames.accountName,
      network: network,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      dataDir: dataDir,
      dustLimit: BigInt.from(minScanAmountSat),
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
      headerCheckpoint: headerCheckpoint,
    )) {
      case Ok(:final value):
        _account = value;
        _blindbitUrl = blindbitUrl;
        return const Ok(null);
      case Err(:final failure):
        return Err(failure);
    }
  }

  /// Tear down the live session and drop every simulation pinned to it.
  Future<void> dispose() async {
    final account = _account;
    if (account == null) return;
    await account.dispose();
    await account.release();
    _account = null;
    _blindbitUrl = null;
    _simulations.clear();
  }

  /// The single-take Rust notification receiver. Taken once per session.
  Stream<SpNotification> init() => _live.init();

  void setElectrumUrl(String url) => _live.setElectrumUrl(url: url);

  Future<void> startElectrum() => _live.startElectrum();

  Future<void> restartElectrum() => _live.restartElectrum();

  String spAddress() => _live.spAddress();

  SpBalanceView unifiedBalance() => _live.unifiedBalance();

  int? lastScannedHeight() => _live.lastScannedHeight();

  Future<String> newTaprootAddress() => _live.newTaprootAddress();

  Future<List<SpPaymentView>> unifiedHistory() => _live.unifiedHistory();

  Future<List<UnifiedCoinView>> unifiedCoins() => _live.unifiedCoins();

  bool restampMissingTimestamps() => _live.restampMissingTimestamps();

  Future<void> scanOnce({int? startHeight}) =>
      _live.scanOnce(startHeight: startHeight);

  Future<void> stopScan() => _live.stopScan();

  void clearScanState() => _live.clearScanState();

  int minBirthdayHeight() => _live.minBirthdayHeight();

  SpNetwork network() => _live.network();

  /// Latest block the session's Blindbit server has indexed, read over HTTP.
  /// The account's own cursor is the electrum tip, which lags the Blindbit
  /// server the scan actually follows.
  Future<int> blockHeight() {
    final url = _blindbitUrl;
    if (url == null) {
      throw StateError('SpAccountDatasource: no live SP session');
    }
    return blindbitTip(url: url);
  }

  /// Simulate the spend and pin the simulation for the live session. The id is
  /// the handle the draft carries back into [finalizeAndSignToHex].
  Future<(String, TxSimulation)> preparePsbt({
    required List<RecipientView> recipients,
    required BigInt feerateSatVb,
    required BigInt changeDustThreshold,
  }) async {
    final simulation = await _live.preparePsbt(
      recipients: recipients,
      feerateSatVb: feerateSatVb,
      changeDustThreshold: changeDustThreshold,
    );
    final id = (_nextDraftId++).toString();
    _simulations[id] = simulation;
    return (id, simulation);
  }

  /// The simulation pinned under [id], or null once the session was recycled.
  TxSimulation? pinnedSimulation(String id) => _simulations[id];

  /// The Rust side pins inputs+outputs to the confirmed simulation and fails
  /// loudly if the coin store drifted, so we never broadcast a tx whose inputs
  /// differ from what was shown on the Confirm page.
  Future<String> finalizeAndSignToHex(TxSimulation simulation) async {
    final account = _live;
    final psbtBytes = await account.finalizePsbt(simulation: simulation);
    final signedBytes = await account.signPsbt(psbt: psbtBytes);
    return signedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> broadcast({required String txHex}) =>
      _live.broadcast(txHex: txHex);

  SpAccount get _live {
    final account = _account;
    if (account == null) {
      throw StateError('SpAccountDatasource: no live SP session');
    }
    return account;
  }
}
