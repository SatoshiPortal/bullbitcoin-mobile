import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_account_files_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_payments_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_control_port.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_scan_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_auto_scan_repository.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_backend_probe_port.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:mocktail/mocktail.dart';

/// Shared mocktail doubles + builders for the SP domain use case tests. The use
/// case tests need `verify()` on collaborator calls, so they mock these two
/// (rather than use the in-memory fakes above). Kept here so the declarations
/// and fixture values live once instead of being copy-pasted per file.
class MockSpAccountRepository extends Mock
    implements
        SpAccountRepository,
        SpAccountFilesPort,
        SpScanPort,
        SpScanControlPort,
        SpPaymentsPort {}

class MockGetDefaultSeedUsecase extends Mock implements GetDefaultSeedUsecase {}

MnemonicSeed spMnemonicSeed() => MnemonicSeed(
  mnemonicWords: List.filled(12, 'abandon'),
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

SpBackendConfig spBackendConfig({
  BitcoinNetwork network = BitcoinNetwork.regtest,
  String blindbitUrl = 'http://blindbit.example',
  String electrumUrl = 'tcp://electrum.example:50001',
}) => SpBackendConfig(
  network: network,
  blindbitUrl: blindbitUrl,
  electrumUrl: electrumUrl,
);

SpWallet spWallet({
  String spAddress = 'sp1qexample',
  Sats? confirmedSat,
  Sats? totalUnifiedSat,
  bool isScanning = false,
  int? lastScannedHeight,
}) => SpWallet(
  spAddress: spAddress,
  balance: SpBalance(
    confirmedSat: confirmedSat ?? Sats.fromInt(10),
    totalUnifiedSat: totalUnifiedSat ?? Sats.fromInt(20),
  ),
  isScanning: isScanning,
  lastScannedHeight: lastScannedHeight,
);

/// In-memory fake of [SpAccountRepository]. The repo-rule prefers fakes over
/// mocks for a datasource/repository: this behaves like a set-up, non-revoked
/// session and, crucially, counts every [scanOnce] call so a test can assert
/// exactly when a scan is and is not triggered.
///
/// Toggle [hasSessionValue] / [sentinel] to model a fresh, revoked, or
/// not-yet-established wallet. All async reads default to `Ok`.
class FakeSpAccountRepository
    implements
        SpAccountRepository,
        SpAccountFilesPort,
        SpScanPort,
        SpScanControlPort,
        SpPaymentsPort {
  FakeSpAccountRepository({
    SpWallet? wallet,
    this.hasSessionValue = true,
    this.sentinel = false,
    this.accountDir = true,
    this.networkValue = BitcoinNetwork.regtest,
    this.backendOnlineValue = true,
  }) : _wallet =
           wallet ??
           SpWallet(
             spAddress: 'sp1qfake',
             balance: SpBalance(
               confirmedSat: Sats.zero,
               totalUnifiedSat: Sats.zero,
             ),
             isScanning: false,
           );

  SpWallet _wallet;
  bool hasSessionValue;
  bool sentinel;
  bool accountDir;
  BitcoinNetwork? networkValue;
  bool backendOnlineValue;

  /// How many times the Rust scan was reached. Stays 0 unless the user
  /// explicitly triggers a scan.
  int scanOnceCount = 0;

  /// Start height of the most recent scan, so a test can assert where it began.
  int? lastScanStartHeight;

  /// Live tip returned by [currentBlockHeight].
  int currentBlockHeightValue = 0;

  /// Model a live tip read that fails (no session, dead FFI).
  bool currentBlockHeightShouldFail = false;

  /// How many times a live session was created (setup / reconstruct).
  int createCount = 0;

  /// Model a create/wipe that fails on disk (used by the setup use case tests).
  bool createShouldFail = false;
  bool wipeShouldFail = false;

  final _notifications = StreamController<SpNotification>.broadcast();
  final _updates = StreamController<SpUpdate>.broadcast();
  final _notifLog = StreamController<SpNotifLogLine>.broadcast();

  void emitNotification(SpNotification n) => _notifications.add(n);

  Future<void> disposeStreams() async {
    await _notifications.close();
    await _updates.close();
    await _notifLog.close();
  }

  @override
  Future<Result<void, SpFailure>> createFromMnemonic({
    required BitcoinNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) async {
    if (createShouldFail) {
      return const Err(SpUnexpected('SP account create failed'));
    }
    createCount++;
    hasSessionValue = true;
    return const Ok(null);
  }

  @override
  Future<Result<void, SpFailure>> dispose() async {
    hasSessionValue = false;
    return const Ok(null);
  }

  @override
  bool get hasSession => hasSessionValue;

  @override
  bool get teardownInProgress => false;

  @override
  void beginTeardown() {}

  @override
  void endTeardown() {}

  @override
  Future<Result<bool, SpFailure>> accountDirExists() async => Ok(accountDir);

  @override
  Future<Result<void, SpFailure>> writeRevokedSentinel({
    bool skipIfPresent = false,
  }) async {
    sentinel = true;
    return const Ok(null);
  }

  @override
  Future<Result<bool, SpFailure>> backupAccountDir() async => const Ok(false);

  @override
  Future<Result<bool, SpFailure>> restoreAccountDir() async => const Ok(false);

  @override
  Future<Result<void, SpFailure>> discardBackup() async => const Ok(null);

  @override
  Future<Result<bool, SpFailure>> adoptNewestBackup() async => const Ok(false);

  @override
  Future<Result<void, SpFailure>> deleteOrphanBackups() async => const Ok(null);

  @override
  Future<Result<bool, SpFailure>> hasRevokedSentinel() async => Ok(sentinel);

  @override
  Future<Result<void, SpFailure>> deleteAccountDir() async {
    if (wipeShouldFail) {
      return const Err(SpUnexpected('account dir delete failed on disk'));
    }
    accountDir = false;
    sentinel = false;
    return const Ok(null);
  }

  @override
  Result<SpWallet, SpFailure> snapshot() => Ok(_wallet);

  @override
  Result<SpBalance, SpFailure> balance() => Ok(_wallet.balance);

  @override
  bool get isScanningCached => _wallet.isScanning;

  @override
  Future<Result<String, SpFailure>> generateTaprootAddress() async =>
      const Ok<String, SpFailure>('bcrt1pfake');

  @override
  Future<Result<List<SpPayment>, SpFailure>> history() async =>
      const Ok<List<SpPayment>, SpFailure>(<SpPayment>[]);

  @override
  Future<Result<List<SpCoin>, SpFailure>> coins() async =>
      const Ok<List<SpCoin>, SpFailure>(<SpCoin>[]);

  @override
  Future<Result<void, SpFailure>> scanOnce({int? startHeight}) async {
    scanOnceCount++;
    lastScanStartHeight = startHeight;
    return const Ok<void, SpFailure>(null);
  }

  @override
  Future<Result<void, SpFailure>> stopScan() async => const Ok(null);

  @override
  Future<Result<void, SpFailure>> clearScanState() async {
    _wallet = SpWallet(
      spAddress: _wallet.spAddress,
      balance: _wallet.balance,
      isScanning: _wallet.isScanning,
    );
    return const Ok<void, SpFailure>(null);
  }

  /// How many times the listener was restarted, and a switch to model a
  /// restart that fails (a dead socket, DNS down).
  int restartElectrumCount = 0;
  bool restartElectrumShouldFail = false;

  /// Set to hold [restartElectrum] open, so a test can suspend a sync tick
  /// mid-flight and fire a second one against it.
  Completer<void>? restartElectrumGate;

  @override
  Future<Result<void, SpFailure>> restartElectrum() async {
    restartElectrumCount++;
    await restartElectrumGate?.future;
    if (restartElectrumShouldFail) {
      return const Err(SpUnexpected('restart failed'));
    }
    return const Ok(null);
  }

  /// Replace the snapshot the port reports, for the scan policy tests.
  void setWalletForTest(SpWallet wallet) => _wallet = wallet;

  /// Model a scan already in flight, which owns the session.
  void setScanningForTest(bool isScanning) {
    _wallet = SpWallet(
      spAddress: _wallet.spAddress,
      balance: _wallet.balance,
      isScanning: isScanning,
      lastScannedHeight: _wallet.lastScannedHeight,
    );
  }

  @override
  Result<int, SpFailure> minBirthdayHeight() => const Ok(0);

  @override
  Future<Result<SpTxDraft, SpFailure>> preparePsbt({
    required List<SpRecipient> recipients,
    required BigInt feerateSatVb,
  }) async =>
      const Err<SpTxDraft, SpFailure>(SpUnexpected('not supported in fake'));

  @override
  Future<Result<String, SpFailure>> finalizeSignBroadcast({
    required SpTxDraft draft,
  }) async =>
      const Err<String, SpFailure>(SpUnexpected('not supported in fake'));

  @override
  Result<BitcoinNetwork?, SpFailure> network() => Ok(networkValue);

  @override
  bool backendOnline() => backendOnlineValue;

  /// Tip reported to the scan policy; null models "header store has not said".
  int? chainTipValue;

  @override
  int? chainTip() => chainTipValue;

  @override
  Result<int, SpFailure> currentBlockHeight() {
    if (currentBlockHeightShouldFail) {
      return const Err(SpUnexpected('no live session'));
    }
    return Ok(currentBlockHeightValue);
  }

  @override
  Stream<SpNotification> get notifications => _notifications.stream;

  @override
  List<SpNotifLogLine> get notificationLog => const <SpNotifLogLine>[];

  @override
  Stream<SpNotifLogLine> get notificationLogStream => _notifLog.stream;

  @override
  Stream<SpUpdate> get updates => _updates.stream;

  @override
  void notifySetupChanged() => _updates.add(const SpSetupChanged());

  @override
  void notifyBalanceChanged(Sats totalUnifiedSat) =>
      _updates.add(SpBalanceChanged(totalUnifiedSat));
}

/// In-memory fake of [SpBackendConfigRepository]. Holds one config; [fetch]
/// returns it (or `Ok(null)` when absent). Set [failFetch] to model a corrupt
/// stored config.
class FakeSpBackendConfigRepository implements SpBackendConfigRepository {
  bool _isSetUp = false;

  @override
  bool get isSetUpNow => _isSetUp;

  @override
  void setIsSetUpNow({required bool isSetUp}) => _isSetUp = isSetUp;

  SpBackendConfig? _config;

  /// Model a corrupt stored config: callers fold this to "not configured".
  bool failFetch = false;

  /// Model the storage read itself failing (a locked keystore). Kept apart from
  /// [failFetch]: this one must never read as "no wallet".
  bool readShouldFail = false;

  /// Model a save that fails on disk (used by the setup use case tests).
  bool saveShouldFail = false;

  @override
  Future<Result<void, SpFailure>> save(SpBackendConfig config) async {
    if (saveShouldFail) {
      return const Err(SpUnexpected('save failed on disk'));
    }
    _config = config;
    return const Ok(null);
  }

  @override
  Future<Result<SpBackendConfig?, SpFailure>> fetch() async {
    if (readShouldFail) {
      return const Err<SpBackendConfig?, SpFailure>(
        SpUnexpected('config read failed'),
      );
    }
    if (failFetch) {
      return const Err<SpBackendConfig?, SpFailure>(
        SpConfigInvalid('corrupt stored config'),
      );
    }
    return Ok<SpBackendConfig?, SpFailure>(_config);
  }

  @override
  Future<Result<void, SpFailure>> delete() async {
    _config = null;
    return const Ok(null);
  }
}

/// In-memory fake of [SpBackendProbePort]. Connecting always succeeds; the
/// regtest fetch resolves to whatever the test set.
class FakeSpBackendProbe implements SpBackendProbePort {
  /// What the regtest fetch resolves to. Left null it fails, which is what the
  /// tests that never take the regtest branch want.
  Result<SpBackendDefaults, SpFailure>? regtestDefaults;
  int fetchRegtestDefaultsCalls = 0;

  @override
  Future<Result<void, SpFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async => const Ok(null);

  @override
  Future<Result<SpBackendDefaults, SpFailure>> fetchRegtestDefaults() async {
    fetchRegtestDefaultsCalls++;
    return regtestDefaults ??
        const Err(SpUnexpected('fetchRegtestDefaults not used in tests'));
  }
}

/// In-memory [KeyValueStorageDatasource], shared by the SP repository tests.
class InMemoryKeyValueStorage implements KeyValueStorageDatasource<String> {
  final Map<String, String> _store = {};

  @override
  Future<void> saveValue({required String key, required String value}) async =>
      _store[key] = value;

  @override
  Future<Map<String, String>> getAll() async => Map.of(_store);

  @override
  Future<String?> getValue(String key) async => _store[key];

  @override
  Future<bool> hasValue(String key) async => _store.containsKey(key);

  @override
  Future<void> deleteValue(String key) async => _store.remove(key);

  @override
  Future<void> deleteAll() async => _store.clear();
}

/// Stands in for a locked keystore: every storage call throws.
class ThrowingKeyValueStorage implements KeyValueStorageDatasource<String> {
  @override
  Future<void> saveValue({required String key, required String value}) async =>
      throw Exception('keystore locked');

  @override
  Future<Map<String, String>> getAll() async =>
      throw Exception('keystore locked');

  @override
  Future<String?> getValue(String key) async =>
      throw Exception('keystore locked');

  @override
  Future<bool> hasValue(String key) async => throw Exception('keystore locked');

  @override
  Future<void> deleteValue(String key) async =>
      throw Exception('keystore locked');

  @override
  Future<void> deleteAll() async => throw Exception('keystore locked');
}

/// In-memory fake of [SpAutoScanRepository]; the choice is not persisted in
/// tests.
class FakeSpAutoScanRepository implements SpAutoScanRepository {
  bool? stored;
  bool _isEnabled = true;

  @override
  bool get isEnabledNow => _isEnabled;

  @override
  Future<void> warmUp() async => _isEnabled = stored ?? true;

  @override
  Future<void> save({required bool isEnabled}) async {
    _isEnabled = isEnabled;
    stored = isEnabled;
  }
}
