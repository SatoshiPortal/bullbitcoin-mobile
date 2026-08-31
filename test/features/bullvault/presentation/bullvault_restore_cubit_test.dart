import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/domain/bullvault_failure.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_restore_result.dart';
import 'package:bb_mobile/features/bullvault/domain/usecases/restore_bullvault_usecase.dart';
import 'package:bb_mobile/features/bullvault/presentation/bullvault_restore_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../bullvault_test_fixture.dart';

class _MockRestoreBullVaultUsecase extends Mock
    implements RestoreBullVaultUsecase {}

void main() {
  late _MockRestoreBullVaultUsecase usecase;

  setUp(() => usecase = _MockRestoreBullVaultUsecase());

  test('publishes a restored wallet after validation succeeds', () async {
    final created = testBullVaultCreateResult(status: .active);
    when(
      () => usecase.execute(
        kind: BullVaultRestoreInputKind.recoveryPackage,
        source: 'package',
        label: 'Vault',
      ),
    ).thenAnswer(
      (_) async => Ok(
        BullVaultRestoreResult(
          wallet: created.wallet,
          record: created.record,
          source: BullVaultRestoreSource.recoveryPackage,
        ),
      ),
    );
    final cubit = BullVaultRestoreCubit(usecase);
    addTearDown(cubit.close);
    final statesFuture = cubit.stream.take(2).toList();

    await cubit.restore(
      kind: BullVaultRestoreInputKind.recoveryPackage,
      source: 'package',
      label: 'Vault',
    );
    final states = await statesFuture;

    expect(states.first.isRestoring, isTrue);
    expect(states.last.isRestoring, isFalse);
    expect(states.last.result?.wallet.id, 'bullvault-wallet');
  });

  test('publishes a typed failure when validation fails', () async {
    when(
      () => usecase.execute(
        kind: BullVaultRestoreInputKind.descriptor,
        source: 'descriptor',
        label: 'Vault',
      ),
    ).thenAnswer((_) async => const Err(BullVaultInvalidRecoveryFailure()));
    final cubit = BullVaultRestoreCubit(usecase);
    addTearDown(cubit.close);
    final statesFuture = cubit.stream.take(2).toList();

    await cubit.restore(
      kind: BullVaultRestoreInputKind.descriptor,
      source: 'descriptor',
      label: 'Vault',
    );
    final states = await statesFuture;

    expect(states.first.isRestoring, isTrue);
    expect(states.last.isRestoring, isFalse);
    expect(states.last.failure, isA<BullVaultInvalidRecoveryFailure>());
  });
}
