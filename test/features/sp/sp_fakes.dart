import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_kind.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_coin.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_network.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_payment.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_recipient.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/repositories/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:mocktail/mocktail.dart';

/// Shared mocktail doubles + builders for the SP domain use case tests. The use
/// case tests need `verify()` on collaborator calls, so they mock these two
/// (rather than use the in-memory fakes above). Kept here so the declarations
/// and fixture values live once instead of being copy-pasted per file.
class MockSpAccountRepository extends Mock implements SpAccountRepository {}

class MockGetDefaultSeedUsecase extends Mock implements GetDefaultSeedUsecase {}

MnemonicSeed spMnemonicSeed() => MnemonicSeed(
  mnemonicWords: List.filled(12, 'abandon'),
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

SpBackendConfig spBackendConfig({
  SpNetwork network = SpNetwork.regtest,
  String blindbitUrl = 'http://blindbit.example',
  String electrumUrl = 'tcp://electrum.example:50001',
}) => SpBackendConfig(
  network: network,
  blindbitUrl: blindbitUrl,
  electrumUrl: electrumUrl,
);

SpWallet spWallet({
  String spAddress = 'sp1qexample',
  BigInt? confirmedSat,
  BigInt? totalUnifiedSat,
  bool isScanning = false,
}) => SpWallet(
  spAddress: spAddress,
  balance: SpBalance(
    confirmedSat: confirmedSat ?? BigInt.from(10),
    totalUnifiedSat: totalUnifiedSat ?? BigInt.from(20),
  ),
  isScanning: isScanning,
);

/// In-memory fake of [SpAccountRepository]. The repo-rule prefers fakes over
/// mocks for a datasource/repository: this behaves like a set-up, non-revoked
/// session and, crucially, counts every [scanOnce] call so a test can assert
/// the scan is never auto-triggered (the SP no-autoscan invariant).
///
/// Toggle [hasSessionValue] / [sentinel] to model a fresh, revoked, or
/// not-yet-established wallet. All async reads default to `Ok`.
class FakeSpAccountRepository implements SpAccountRepository {
  FakeSpAccountRepository({
    SpWallet? wallet,
    this.hasSessionValue = true,
    this.sentinel = false,
    this.networkValue = SpNetwork.regtest,
    this.backendOnlineValue = true,
  }) : _wallet =
           wallet ??
           SpWallet(
             spAddress: 'sp1qfake',
             balance: SpBalance(
               confirmedSat: BigInt.zero,
               totalUnifiedSat: BigInt.zero,
             ),
             isScanning: false,
           );

  SpWallet _wallet;
  bool hasSessionValue;
  bool sentinel;
  SpNetwork? networkValue;
  bool backendOnlineValue;

  /// How many times the Rust scan was reached. Stays 0 unless the user
  /// explicitly triggers a scan.
  int scanOnceCount = 0;

  /// How many times a live session was created (setup / reconstruct).
  int createCount = 0;

  /// Model a create/wipe that fails on disk (used by the setup use case tests).
  bool createShouldThrow = false;
  bool wipeShouldThrow = false;

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
  Future<void> createFromMnemonic({
    required SpNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
    int fetchConcurrencyFactor = SpConfig.defaultFetchConcurrencyFactor,
    int matchConcurrencyFactor = SpConfig.defaultMatchConcurrencyFactor,
  }) async {
    if (createShouldThrow) throw Exception('create failed on disk');
    createCount++;
    hasSessionValue = true;
  }

  @override
  Future<void> dispose() async {
    hasSessionValue = false;
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
  Future<void> revokeOnDisk() async {
    sentinel = true;
    hasSessionValue = false;
  }

  @override
  Future<bool> backupAccountDir() async => false;

  @override
  Future<bool> restoreAccountDir() async => false;

  @override
  Future<void> discardBackup() async {}

  @override
  Future<bool> hasRevokedSentinel() async => sentinel;

  @override
  Future<void> wipeStaleAccountDir() async {
    if (wipeShouldThrow) throw Exception('wipe failed on disk');
    sentinel = false;
  }

  @override
  SpWallet snapshot() => _wallet;

  @override
  SpBalance balance() => _wallet.balance;

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
    return const Ok<void, SpFailure>(null);
  }

  @override
  Future<void> stopScan() async {}

  @override
  Future<Result<void, SpFailure>> clearScanState() async {
    _wallet = SpWallet(
      spAddress: _wallet.spAddress,
      balance: _wallet.balance,
      isScanning: _wallet.isScanning,
    );
    return const Ok<void, SpFailure>(null);
  }

  @override
  Future<void> restartElectrum() async {}

  @override
  int minBirthdayHeight() => 0;

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
  SpNetwork? network() => networkValue;

  @override
  bool backendOnline() => backendOnlineValue;

  @override
  int? chainTip() => null;

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
  void notifyBalanceChanged(BigInt totalUnifiedSat) =>
      _updates.add(SpBalanceChanged(totalUnifiedSat));
}

/// In-memory fake of [SpBackendConfigRepository]. Holds one config; [fetch]
/// returns it (or `Ok(null)` when absent). Set [failFetch] to model a corrupt
/// stored config.
class FakeSpBackendConfigRepository implements SpBackendConfigRepository {
  SpBackendConfig? _config;
  bool failFetch = false;

  /// Model a save that fails on disk (used by the setup use case tests).
  bool saveShouldThrow = false;

  @override
  Future<void> save(SpBackendConfig config) async {
    if (saveShouldThrow) throw Exception('save failed on disk');
    _config = config;
  }

  @override
  Future<Result<SpBackendConfig?, SpFailure>> fetch() async {
    if (failFetch) {
      return const Err<SpBackendConfig?, SpFailure>(
        SpConfigInvalid('corrupt stored config'),
      );
    }
    return Ok<SpBackendConfig?, SpFailure>(_config);
  }

  @override
  Future<void> delete() async {
    _config = null;
  }

  @override
  Future<Result<void, SpFailure>> testBackend(
    SpBackendKind kind,
    String url,
  ) async => const Ok(null);

  @override
  Future<Result<SpBackendDefaults, SpFailure>> fetchRegtestDefaults() async =>
      const Err(SpUnexpected('fetchRegtestDefaults not used in tests'));
}
