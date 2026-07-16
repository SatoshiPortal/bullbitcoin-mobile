import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_electrum_sync_results_usecase.dart';
import 'package:bb_mobile/features/keychain_manifest/domain/usecases/flush_keychain_manifest_backup_usecase.dart';
import 'package:flutter/widgets.dart';

final class KeychainManifestBackupWatcher {
  final WatchElectrumSyncResultsUsecase watchSyncResults;
  final FlushKeychainManifestBackupUsecase flush;
  StreamSubscription<void>? _syncSubscription;
  AppLifecycleListener? _lifecycle;

  KeychainManifestBackupWatcher({
    required this.watchSyncResults,
    required this.flush,
  });

  void start() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(onResume: _retry);
    _syncSubscription = watchSyncResults
        .execute()
        .where((result) {
          return result.success;
        })
        .listen((_) => _retry());
    _retry();
  }

  void _retry() {
    unawaited(
      flush.execute().catchError((Object error, StackTrace stack) {
        log.warning(
          'Keychain manifest backup retry failed',
          error: error,
          trace: stack,
        );
      }),
    );
  }

  Future<void> dispose() async {
    _lifecycle?.dispose();
    _lifecycle = null;
    await _syncSubscription?.cancel();
    _syncSubscription = null;
  }
}
