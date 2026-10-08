import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

/// Reads the RecoverBull encrypted-backup status of the network that
/// [Environment] selects; each network keeps its own status.
class GetEncryptedBackupStatusUsecase {
  final Future<RecoverBullStatus> Function(RecoverBullNetwork)
  _recoverBullStatus;

  GetEncryptedBackupStatusUsecase({required this._recoverBullStatus});

  Future<RecoverBullStatus> execute(Environment environment) =>
      _recoverBullStatus(
        environment.isTestnet
            ? RecoverBullNetwork.testnet
            : RecoverBullNetwork.mainnet,
      );
}
