import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/receive/domain/usecases/check_receive_bullvault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBullVaultFacade extends Mock implements BullVaultFacade {}

void main() {
  late _MockBullVaultFacade facade;
  late CheckReceiveBullVaultUsecase usecase;

  setUp(() {
    facade = _MockBullVaultFacade();
    usecase = CheckReceiveBullVaultUsecase(facade);
  });

  test('identifies a wallet with BullVault metadata', () async {
    when(
      () => facade.isBullVaultWallet('vault'),
    ).thenAnswer((_) async => const Ok(true));

    expect(await usecase.execute('vault'), isTrue);
  });

  test(
    'does not show the reminder when BullVault metadata is unavailable',
    () async {
      when(
        () => facade.isBullVaultWallet('wallet'),
      ).thenAnswer((_) async => const Ok(false));

      expect(await usecase.execute('wallet'), isFalse);
    },
  );

  test('shows the reminder when BullVault metadata cannot be read', () async {
    when(
      () => facade.isBullVaultWallet('wallet'),
    ).thenAnswer((_) async => const Err(BullVaultRenewalFailure()));

    expect(await usecase.execute('wallet'), isTrue);
  });
}
