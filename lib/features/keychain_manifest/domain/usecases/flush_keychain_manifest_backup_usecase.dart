import 'dart:async';

import 'package:bb_mobile/core/utils/clock.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_backup_wallet.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/entities/keychain_manifest_remote_backup.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/keychain_manifest_error.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/repositories/keychain_manifest_backup_state_repository.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/sync_keychain_manifest_backup_usecase.dart';

final class FlushKeychainManifestBackupUsecase {
  final KeychainManifestBackupStateRepository state;
  final KeychainManifestBackupWalletPort wallet;
  final SyncKeychainManifestBackupUsecase sync;
  final Clock clock;
  Future<void>? _inFlight;
  bool _runAgain = false;

  FlushKeychainManifestBackupUsecase({
    required this.state,
    required this.wallet,
    required this.sync,
    this.clock = const SystemClock(),
  });

  Future<void> execute() {
    final running = _inFlight;
    if (running != null) {
      _runAgain = true;
      return running;
    }
    final operation = _drain();
    _inFlight = operation;
    return operation.whenComplete(() {
      if (identical(_inFlight, operation)) _inFlight = null;
    });
  }

  Future<void> _drain() async {
    do {
      _runAgain = false;
      await _flush();
    } while (_runAgain);
  }

  Future<void> _flush() async {
    final before = await state.get();
    if (!before.enabled || !before.dirty || before.unsupportedVersion != null) {
      return;
    }
    final attemptedAt = clock.nowSecs();
    await state.recordAttempt(attemptedAt);
    final source = await wallet.deriveDefaultWallet();
    final KeychainManifestBackupSyncResult result;
    try {
      result = await sync.execute(
        parentFingerprint: source.parentFingerprint,
        xprvBase58: source.xprvBase58,
        now: DateTime.fromMillisecondsSinceEpoch(
          attemptedAt * 1000,
          isUtc: true,
        ),
      );
    } on KeychainManifestEmptyInventoryException {
      return;
    } on KeychainManifestUnsupportedVersionException catch (error) {
      await state.blockUnsupportedVersion(error.version);
      rethrow;
    }
    await state.recordSuccess(
      capturedDirtyRevision: before.dirtyRevision,
      succeededAt: clock.nowSecs(),
      checkpoint: result.checkpoint,
      contentHash: result.contentHash,
    );
  }
}
