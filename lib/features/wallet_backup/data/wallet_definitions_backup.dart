import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_definitions_section.dart';

final class WalletDefinitionsBackupImpl implements WalletDefinitionsBackup {
  final Future<List<WalletDefinition>> Function() _getDefinitions;
  final Future<WalletDefinitionRestoreResult> Function(WalletDefinition)
  _restoreDefinition;
  final Stream<void> Function() _watchChanges;
  final DateTime Function() _nowUtc;

  const WalletDefinitionsBackupImpl(
    this._getDefinitions,
    this._restoreDefinition,
    this._watchChanges, {
    this._nowUtc = _systemNowUtc,
  });

  @override
  Stream<void> get changes => _watchChanges();

  @override
  Future<Result<List<WalletDefinition>, WalletBackupFailure>> read() async {
    try {
      return Ok(
        (await _getDefinitions())
            .where((definition) => definition.network.isBitcoin)
            .toList(growable: false),
      );
    } on Exception catch (error) {
      return Err(WalletBackupDefinitionsFailure(error.runtimeType.toString()));
    }
  }

  @override
  Future<Result<WalletDefinitionsRecoveryResult, WalletBackupFailure>> recover({
    required List<WalletDefinition> definitions,
    DateTime? deadline,
  }) async {
    var restored = 0;
    var failed = 0;
    final created = <String>[];
    for (var index = 0; index < definitions.length; index++) {
      if (deadline != null && !_nowUtc().isBefore(deadline)) {
        failed += definitions.length - index;
        break;
      }
      try {
        final result = await _restoreDefinition(definitions[index]);
        switch (result.status) {
          case WalletDefinitionRestoreStatus.created:
            restored++;
            created.add(result.walletRef);
          case WalletDefinitionRestoreStatus.alreadyPresent:
            restored++;
          case WalletDefinitionRestoreStatus.conflict:
            failed++;
        }
      } on Exception {
        failed++;
      }
    }
    return Ok(
      WalletDefinitionsRecoveryResult(
        restoredCount: restored,
        failedCount: failed,
        createdWalletRefs: created,
      ),
    );
  }
}

DateTime _systemNowUtc() => DateTime.now().toUtc();
