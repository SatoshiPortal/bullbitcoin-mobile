import 'package:silent/src/domain/usecases/get_sp_feature_gate_usecase.dart';

import 'dart:async';

import 'package:silent/src/domain/usecases/get_sp_secret_usecase.dart';
import 'package:silent/src/domain/entities/sp_backend_kind.dart';
import 'package:silent/src/domain/entities/sp_backend_defaults.dart';
import 'package:silent/src/domain/entities/sp_coin.dart';
import 'package:primitives/primitives.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/domain/entities/sp_payment.dart';
import 'package:silent/src/domain/entities/sp_recipient.dart';
import 'package:silent/src/domain/entities/sp_tx_draft.dart';
import 'package:silent/src/domain/ports/sp_account_files_port.dart';
import 'package:silent/src/domain/ports/sp_payments_port.dart';
import 'package:silent/src/domain/ports/sp_scan_control_port.dart';
import 'package:silent/src/domain/ports/sp_scan_port.dart';
import 'package:silent/src/domain/repositories/sp_account_repository.dart';
import 'package:silent/src/domain/repositories/sp_auto_scan_repository.dart';
import 'package:silent/src/domain/ports/sp_backend_probe_port.dart';
import 'package:silent/src/domain/repositories/sp_backend_config_repository.dart';
import 'package:silent/src/domain/entities/sp_backend_config.dart';
import 'package:silent/src/domain/entities/sp_balance.dart';
import 'package:silent/src/domain/sp_config.dart';
import 'package:silent/src/domain/silent_failure.dart';
import 'package:silent/src/domain/entities/sp_notif_log.dart';
import 'package:silent/src/domain/entities/sp_update.dart';
import 'package:silent/src/domain/entities/sp_wallet.dart';
import 'package:mocktail/mocktail.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

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

class MockGetSpSecretUsecase extends Mock implements GetSpSecretUsecase {}

/// A real handle over an in-memory keystore: `Secret` is final, so it cannot
/// be mocked, and a handle carries no words anyway.
Future<Secret> spSecret() async {
  FakeSecureStoragePlatform().install();
  final secrets = Secrets(scratchDirectory: () async => '/tmp');
  final imported = await secrets.import(
    words: [...List.filled(11, 'abandon'), 'about'],
    language: Language.english,
  );
  return (imported as Ok<Secret, SecretFailure>).value;
}

SpBackendConfig spBackendConfig({
  BitcoinNetwork network = BitcoinNetwork.regtest,
  String blindbitUrl = 'http://blindbit.example',
  String electrumUrl = 'tcp://electrum.example:50001',
}) => SpBackendConfig(
  network: network,
  blindbitUrl: blindbitUrl,
  electrumUrl: electrumUrl,
);

SilentWallet spWallet({
  BitcoinNetwork? network = BitcoinNetwork.mainnet,
  String spAddress = 'sp1qexample',
  Sats? confirmedSat,
  Sats? totalUnifiedSat,
  bool isScanning = false,
  int? lastScannedHeight,
}) {
  final balance = SilentBalance(
    confirmedSat: confirmedSat ?? Sats.fromInt(10),
    totalUnifiedSat: totalUnifiedSat ?? Sats.fromInt(20),
  );
  // The exact regression suite also runs against the pre-provenance API.
  try {
    return Function.apply(SilentWallet.new, const [], {
      #network: network,
      #spAddress: spAddress,
      #balance: balance,
      #isScanning: isScanning,
      #lastScannedHeight: lastScannedHeight,
    }) as SilentWallet;
  } on NoSuchMethodError {
    return SilentWallet(
      spAddress: spAddress,
      balance: balance,
      isScanning: isScanning,
      lastScannedHeight: lastScannedHeight,
    );
  }
}

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
    SilentWallet? wallet,
    this.hasSessionValue = true,
    this.sentinel = false,
    this.accountDir = true,
    this.networkValue = BitcoinNetwork.regtest,
  }) : _wallet =
           wallet ??
           SilentWallet(
             spAddress: 'sp1qfake',
             balance: SilentBalance(
               confirmedSat: Sats.zero,
               totalUnifiedSat: Sats.zero,
             ),
             isScanning: false,
           );

  SilentWallet _wallet;
  bool hasSessionValue;
  bool sentinel;
  bool accountDir;
  BitcoinNetwork? networkValue;

  /// How many times the Rust scan was reached. Stays 0 unless the user
  /// explicitly triggers a scan.
  int scanOnceCount = 0;

  /// Start height of the most recent scan, so a test can assert where it began.
  int? lastScanStartHeight;

  /// Live tip returned by [currentBlockHeight].
  int currentBlockHeightValue = 0;

  /// Model a live tip read that fails (no session, dead FFI).
  bool currentBlockHeightShouldFail = false;

  /// When set, [currentBlockHeight] returns this future instead, so a test can
  /// hold the read open (timeout and cancellation cases).
  Future<Result<int, SilentFailure>>? currentBlockHeightOverride;

  /// How many times a live session was created (setup / reconstruct).
  int createCount = 0;

  /// Model a create/wipe that fails on disk (used by the setup use case tests).
  bool createShouldFail = false;
  bool wipeShouldFail = false;

  final _notifications = StreamController<SpNotification>.broadcast();
  final _updates = StreamController<SilentUpdate>.broadcast();
  final _notifLog = StreamController<SpNotifLogLine>.broadcast();

  void emitNotification(SpNotification n) => _notifications.add(n);

  Future<void> disposeStreams() async {
    await _notifications.close();
    await _updates.close();
    await _notifLog.close();
  }

  @override
  Future<Result<void, SilentFailure>> createFromSecret({
    required BitcoinNetwork network,
    required Secret secret,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) async {
    if (createShouldFail) {
      return const Err(SilentUnexpected('SP account create failed'));
    }
    createCount++;
    hasSessionValue = true;
    return const Ok(null);
  }

  @override
  Future<Result<void, SilentFailure>> dispose() async {
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
  Future<Result<bool, SilentFailure>> accountDirExists() async =>
      Ok(accountDir);

  @override
  Future<Result<void, SilentFailure>> writeRevokedSentinel({
    bool skipIfPresent = false,
  }) async {
    sentinel = true;
    return const Ok(null);
  }

  @override
  Future<Result<bool, SilentFailure>> backupAccountDir() async =>
      const Ok(false);

  @override
  Future<Result<bool, SilentFailure>> restoreAccountDir() async =>
      const Ok(false);

  @override
  Future<Result<void, SilentFailure>> discardBackup() async => const Ok(null);

  @override
  Future<Result<bool, SilentFailure>> adoptNewestBackup() async =>
      const Ok(false);

  @override
  Future<Result<void, SilentFailure>> deleteOrphanBackups() async =>
      const Ok(null);

  @override
  Future<Result<bool, SilentFailure>> hasRevokedSentinel() async =>
      Ok(sentinel);

  @override
  Future<Result<void, SilentFailure>> deleteAccountDir() async {
    if (wipeShouldFail) {
      return const Err(SilentUnexpected('account dir delete failed on disk'));
    }
    accountDir = false;
    sentinel = false;
    return const Ok(null);
  }

  @override
  Result<SilentWallet, SilentFailure> snapshot() => Ok(_wallet);

  @override
  Result<SilentBalance, SilentFailure> balance() => Ok(_wallet.balance);

  @override
  bool get isScanningCached => _wallet.isScanning;

  @override
  Future<Result<String, SilentFailure>> generateTaprootAddress() async =>
      const Ok<String, SilentFailure>('bcrt1pfake');

  @override
  Future<Result<List<SpPayment>, SilentFailure>> history() async =>
      const Ok<List<SpPayment>, SilentFailure>(<SpPayment>[]);

  @override
  Future<Result<List<SpCoin>, SilentFailure>> coins() async =>
      const Ok<List<SpCoin>, SilentFailure>(<SpCoin>[]);

  /// How many times the missing tx times were restamped.
  int restampCount = 0;

  @override
  Result<void, SilentFailure> restampMissingTimestamps() {
    restampCount++;
    return const Ok(null);
  }

  @override
  Future<Result<void, SilentFailure>> scanOnce({int? startHeight}) async {
    scanOnceCount++;
    lastScanStartHeight = startHeight;
    return const Ok<void, SilentFailure>(null);
  }

  @override
  Future<Result<void, SilentFailure>> stopScan() async => const Ok(null);

  @override
  Future<Result<void, SilentFailure>> clearScanState() async {
    _wallet = SilentWallet(
      spAddress: _wallet.spAddress,
      balance: _wallet.balance,
      isScanning: _wallet.isScanning,
    );
    return const Ok<void, SilentFailure>(null);
  }

  /// How many times the listener was restarted.
  int restartElectrumCount = 0;

  @override
  Future<Result<void, SilentFailure>> restartElectrum() async {
    restartElectrumCount++;
    return const Ok(null);
  }

  /// Replace the snapshot the port reports, for the scan policy tests.
  void setWalletForTest(SilentWallet wallet) => _wallet = wallet;

  /// Model a scan already in flight, which owns the session.
  void setScanningForTest(bool isScanning) {
    _wallet = SilentWallet(
      spAddress: _wallet.spAddress,
      balance: _wallet.balance,
      isScanning: isScanning,
      lastScannedHeight: _wallet.lastScannedHeight,
    );
  }

  @override
  Result<int, SilentFailure> minBirthdayHeight() => const Ok(0);

  @override
  Future<Result<SilentTxDraft, SilentFailure>> preparePsbt({
    required List<SilentRecipient> recipients,
    required BigInt feerateSatVb,
  }) async => const Err<SilentTxDraft, SilentFailure>(
    SilentUnexpected('not supported in fake'),
  );

  @override
  Future<Result<String, SilentFailure>> finalizeSignBroadcast({
    required SilentTxDraft draft,
  }) async => const Err<String, SilentFailure>(
    SilentUnexpected('not supported in fake'),
  );

  @override
  Result<BitcoinNetwork?, SilentFailure> network() => Ok(networkValue);

  /// Tip reported to the scan policy; null models "header store has not said".
  int? chainTipValue;

  @override
  int? chainTip() => chainTipValue;

  @override
  Future<Result<int, SilentFailure>> currentBlockHeight() async {
    final override = currentBlockHeightOverride;
    if (override != null) return override;
    if (currentBlockHeightShouldFail) {
      return const Err(SilentUnexpected('no live session'));
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
  Stream<SilentUpdate> get updates => _updates.stream;

  @override
  void notifySetupChanged() => _updates.add(const SilentSetupChanged());

  @override
  void notifyBalanceChanged(Sats totalUnifiedSat) =>
      _updates.add(SilentBalanceChanged(totalUnifiedSat));
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
  Future<Result<void, SilentFailure>> save(SpBackendConfig config) async {
    if (saveShouldFail) {
      return const Err(SilentUnexpected('save failed on disk'));
    }
    _config = config;
    return const Ok(null);
  }

  @override
  Future<Result<SpBackendConfig?, SilentFailure>> fetch() async {
    if (readShouldFail) {
      return const Err<SpBackendConfig?, SilentFailure>(
        SilentUnexpected('config read failed'),
      );
    }
    if (failFetch) {
      return const Err<SpBackendConfig?, SilentFailure>(
        SilentConfigInvalid('corrupt stored config'),
      );
    }
    return Ok<SpBackendConfig?, SilentFailure>(_config);
  }

  @override
  Future<Result<void, SilentFailure>> delete() async {
    _config = null;
    return const Ok(null);
  }
}

/// In-memory fake of [SpBackendProbePort]. Connecting always succeeds; the
/// regtest fetch resolves to whatever the test set.
class FakeSpBackendProbe implements SpBackendProbePort {
  /// What the regtest fetch resolves to. Left null it fails, which is what the
  /// tests that never take the regtest branch want.
  Result<SpBackendDefaults, SilentFailure>? regtestDefaults;
  int fetchRegtestDefaultsCalls = 0;

  @override
  Future<Result<void, SilentFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async => const Ok(null);

  @override
  Future<Result<SpBackendDefaults, SilentFailure>>
  fetchRegtestDefaults() async {
    fetchRegtestDefaultsCalls++;
    return regtestDefaults ??
        const Err(SilentUnexpected('fetchRegtestDefaults not used in tests'));
  }
}

SilentPaymentKeychain spKeychain(FakeSecureStoragePlatform platform) {
  platform.install();
  return Secrets(scratchDirectory: () async => '/tmp').silentPaymentKeychain;
}

/// In-memory fake of [SpAutoScanRepository]; the choice is not persisted in
/// tests.
class FakeSpAutoScanRepository implements SpAutoScanRepository {
  bool? stored;
  bool _isEnabled = true;

  @override
  bool get isEnabledNow => _isEnabled;

  @override
  Future<Result<void, SilentFailure>> warmUp() async {
    _isEnabled = stored ?? true;
    return const Ok(null);
  }

  @override
  Future<Result<void, SilentFailure>> save({required bool isEnabled}) async {
    _isEnabled = isEnabled;
    stored = isEnabled;
    return const Ok(null);
  }
}

class FakeSpFeatureGateUsecase implements GetSpFeatureGateUsecase {
  bool allowed;
  FakeSpFeatureGateUsecase({this.allowed = true});
  @override
  Future<bool> execute({
    BitcoinNetwork? network,
    SpBackendConfig? config,
    bool allowUnconfigured = false,
  }) async => allowed;

  @override
  Future<Result<bool, SilentFailure>> check({
    BitcoinNetwork? network,
    SpBackendConfig? config,
    bool allowUnconfigured = false,
  }) async => Ok(allowed);
}
