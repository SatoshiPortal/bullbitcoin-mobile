import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_publication.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';

final class WalletBackupJobStatus {
  final bool running;
  final Result<WalletBackupPublication, WalletBackupFailure>? result;
  const WalletBackupJobStatus({this.running = false, this.result});
}
