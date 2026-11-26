import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('forwards the capability result and maps failure', () async {
    rb.Result<bool, rb.RecoverBullFailure> result = const Ok(true);
    final usecase = CheckBackupNeededUsecase(backupWarning: () async => result);
    expect(await usecase.execute(), isA<Ok<bool, WalletFailure>>());
    result = const Err(rb.VaultStorageFailure());
    expect(await usecase.execute(), isA<Err<bool, WalletFailure>>());
  });
}
