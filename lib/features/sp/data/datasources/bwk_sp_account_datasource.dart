import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bull_sdk/bwk.dart';

/// The bwk Silent Payments FFI: one live `SpAccount` and the simulations pinned
/// to it.
///
/// Speaks FFI view types only and throws whatever the boundary throws; the
/// repository maps both to domain types and typed failures.
class BwkSpAccountDatasource {
  SpAccount? _account;

  // Confirmed FFI simulations pinned for the live session, keyed by draft id.
  // The simulation must round-trip UNCHANGED from preparePsbt into signing and
  // finalize, so it stays here (never crosses the domain boundary) and is
  // cleared on dispose.
  final Map<String, TxSimulation> _simulations = {};
  int _nextDraftId = 0;

  bool get hasSession => _account != null;

  /// Opens a watch-only account from its two descriptors: it scans,
  /// simulates, derives addresses and verifies signed PSBTs, but holds no
  /// spend authority and cannot sign. Async because the bwk-dart constructor is
  /// not `#[frb(sync)]`: FRB runs it on a worker isolate so the sqlite open and
  /// the header store open do not freeze the UI isolate.
  Future<void> createFromDescriptors({
    required SpNetwork network,
    required String spDescriptor,
    required String taprootDescriptor,
    required String blindbitUrl,
    required String electrumUrl,
    required String dataDir,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
  }) async {
    _account = await SpAccount.createFromDescriptors(
      name: SpStorageNames.accountName,
      network: network,
      spDescriptor: spDescriptor,
      taprootDescriptor: taprootDescriptor,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      dataDir: dataDir,
      dustLimit: BigInt.from(SpConfig.dustLimitSat),
      fetchConcurrencyFactor: fetchConcurrencyFactor,
      matchConcurrencyFactor: matchConcurrencyFactor,
    );
  }

  /// Tear down the live session and drop every simulation pinned to it.
  Future<void> dispose() async {
    final account = _account;
    if (account == null) return;
    await account.dispose();
    _account = null;
    _simulations.clear();
  }

  /// The single-take Rust notification receiver. Taken once per session.
  Stream<SpNotification> init() => _live.init();

  void setElectrumUrl(String url) => _live.setElectrumUrl(url: url);

  Future<void> startElectrum() => _live.startElectrum();

  Future<void> restartElectrum() => _live.restartElectrum();

  String spAddress() => _live.spAddress();

  SpBalanceView unifiedBalance() => _live.unifiedBalance();

  bool isScanning() => _live.isScanning();

  int? lastScannedHeight() => _live.lastScannedHeight();

  Future<String> newTaprootAddress() => _live.newTaprootAddress();

  Future<List<SpPaymentView>> unifiedHistory() => _live.unifiedHistory();

  Future<List<UnifiedCoinView>> unifiedCoins() => _live.unifiedCoins();

  Future<void> scanOnce({int? startHeight}) =>
      _live.scanOnce(startHeight: startHeight);

  Future<void> stopScan() => _live.stopScan();

  void clearScanState() => _live.clearScanState();

  int minBirthdayHeight() => _live.minBirthdayHeight();

  SpNetwork network() => _live.network();

  bool backendOnline() => _live.backendOnline();

  int blockHeight() => _live.blockHeight();

  /// Simulate the spend and pin the simulation for the live session. The id is
  /// the handle the draft carries back to the signing call.
  Future<(String, TxSimulation)> preparePsbt({
    required List<RecipientView> recipients,
    required BigInt feerateSatVb,
  }) async {
    final simulation = await _live.preparePsbt(
      recipients: recipients,
      feerateSatVb: feerateSatVb,
    );
    final id = (_nextDraftId++).toString();
    _simulations[id] = simulation;
    return (id, simulation);
  }

  /// The simulation pinned under [id], or null once the session was recycled.
  TxSimulation? pinnedSimulation(String id) => _simulations[id];

  /// The live account, for a send pinned to it: the repository takes it
  /// before the custody package signs, checks it is still the live one
  /// afterwards, and has that same account verify the signed PSBT
  /// ([SpAccount.finalize]) and report which outputs of the transaction it owns
  /// ([SpAccount.ownedOutputs]). It holds no spend authority.
  SpAccount get liveAccount => _live;

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
