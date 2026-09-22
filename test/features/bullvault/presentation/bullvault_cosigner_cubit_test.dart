import 'dart:async';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/import_bullvault_cosigner_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_cosigner_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../bullvault_test_fixture.dart';

class _Import extends Mock implements ImportBullVaultCosignerUsecase {}

void main() {
  test('one pending attachment, selected wallet, public result only', () async {
    final usecase = _Import();
    final pending = Completer<Result<Wallet, BullVaultFailure>>();
    when(
      () => usecase.execute(
        walletId: 'selected',
        words: ['fixture'],
        passphrase: 'fixture-passphrase',
      ),
    ).thenAnswer((_) => pending.future);
    final cubit = BullVaultCosignerCubit(usecase, walletId: 'selected');
    addTearDown(cubit.close);
    final first = cubit.attach(
      words: ['fixture'],
      passphrase: 'fixture-passphrase',
    );
    expect(cubit.state, isA<BullVaultCosignerImporting>());
    await cubit.attach(words: ['fixture'], passphrase: 'fixture-passphrase');
    pending.complete(Ok(testBullVaultCreateResult().wallet));
    await first;
    expect(cubit.state, isA<BullVaultCosignerAttached>());
    verify(
      () => usecase.execute(
        walletId: 'selected',
        words: ['fixture'],
        passphrase: 'fixture-passphrase',
      ),
    ).called(1);
  });
  test('failure remains visible and permits correction', () async {
    final usecase = _Import();
    when(
      () => usecase.execute(walletId: 'selected', words: ['fixture']),
    ).thenAnswer((_) async => const Err(BullVaultInvalidSignerFailure()));
    final cubit = BullVaultCosignerCubit(usecase, walletId: 'selected');
    addTearDown(cubit.close);
    await cubit.attach(words: ['fixture']);
    expect(cubit.state, isA<BullVaultCosignerFailed>());
    when(
      () => usecase.execute(walletId: 'selected', words: ['fixture']),
    ).thenAnswer((_) async => Ok(testBullVaultCreateResult().wallet));
    await cubit.attach(words: ['fixture']);
    expect(cubit.state, isA<BullVaultCosignerAttached>());
  });
  test('closing the route does not emit a late result', () async {
    final usecase = _Import();
    final pending = Completer<Result<Wallet, BullVaultFailure>>();
    when(
      () => usecase.execute(walletId: 'selected', words: ['fixture']),
    ).thenAnswer((_) => pending.future);
    final cubit = BullVaultCosignerCubit(usecase, walletId: 'selected');
    final run = cubit.attach(words: ['fixture']);
    await cubit.close();
    pending.complete(const Err(BullVaultInvalidSignerFailure()));
    await run;
    expect(cubit.state, isA<BullVaultCosignerImporting>());
  });
}
