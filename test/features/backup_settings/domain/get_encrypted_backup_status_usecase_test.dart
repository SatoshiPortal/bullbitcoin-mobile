import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/backup_settings/domain/get_encrypted_backup_status_usecase.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final (environment, network) in [
    (Environment.mainnet, RecoverBullNetwork.mainnet),
    (Environment.testnet, RecoverBullNetwork.testnet),
  ]) {
    test('reads the ${network.name} status in $environment', () async {
      final asked = <RecoverBullNetwork>[];
      final status = RecoverBullStatus(lastEncryptedBackupAt: DateTime(2026));
      final usecase = GetEncryptedBackupStatusUsecase(
        recoverBullStatus: (network) async {
          asked.add(network);
          return status;
        },
      );

      expect(await usecase.execute(environment), same(status));
      expect(asked, [network]);
    });
  }
}
