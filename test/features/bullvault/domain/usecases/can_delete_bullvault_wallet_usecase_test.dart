import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_record.dart';
import 'package:bb_mobile/features/bullvault/domain/repositories/bullvault_repository.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/can_delete_bullvault_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../bullvault_test_fixture.dart';

class _MockRepository extends Mock implements BullVaultRepository {}

void main() {
  test('blocks deletion only for wallets in a BullVault lineage', () async {
    final repository = _MockRepository();
    final usecase = CanDeleteBullVaultWalletUsecase(repository);
    when(
      () => repository.getByWalletId('ordinary-wallet'),
    ).thenAnswer((_) async => const Ok(null));
    when(() => repository.getByWalletId('bullvault-wallet')).thenAnswer(
      (_) async => Ok(
        BullVaultRecord(
          walletId: 'bullvault-wallet',
          lineageId: 'lineage-id',
          vaultGeneration: 0,
          mobileAccount: 0,
          birthHeight: 1,
          recoveryPackage: testBullVaultRecoveryPackage(
            lineageId: 'lineage-id',
          ),
          createdAt: DateTime.utc(2027),
        ),
      ),
    );

    expect(_value(await usecase.execute('ordinary-wallet')), isTrue);
    expect(_value(await usecase.execute('bullvault-wallet')), isFalse);
  });
}

bool _value(Result<bool, BullVaultFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err() => throw TestFailure('Unexpected failure'),
};
