import 'package:bb_mobile/features/sp/domain/repositories/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/usecases/refresh_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSpAccountRepository extends Mock implements SpAccountRepository {}

class MockGetSpWalletUsecase extends Mock implements GetSpWalletUsecase {}

SpWallet _wallet() => SpWallet(
      spAddress: 'sp1qexample',
      balance: SpBalance(
        confirmedSat: BigInt.from(5000),
        totalUnifiedSat: BigInt.from(5000),
      ),
      isScanning: false,
    );

void main() {
  late MockSpAccountRepository repository;
  late MockGetSpWalletUsecase getSpWallet;
  late RefreshSpWalletUsecase usecase;

  setUp(() {
    repository = MockSpAccountRepository();
    getSpWallet = MockGetSpWalletUsecase();
    usecase = RefreshSpWalletUsecase(
      repository: repository,
      getSpWalletUsecase: getSpWallet,
    );
  });

  group('RefreshSpWalletUsecase', () {
    test('A: returns the GetSpWalletUsecase snapshot', () async {
      final wallet = _wallet();
      when(() => getSpWallet.execute()).thenAnswer((_) async => wallet);

      final result = await usecase.execute();

      expect(result, same(wallet));
      verify(() => getSpWallet.execute()).called(1);
    });

    test('B: never disposes the live session, even when one exists', () async {
      // Regression guard: disposing here tore the session out from under a
      // running background scan. The live snapshot is already current, so the
      // refresh must reuse it, never dispose + reload.
      when(() => repository.hasSession).thenReturn(true);
      when(() => getSpWallet.execute()).thenAnswer((_) async => _wallet());

      await usecase.execute();

      verifyNever(() => repository.dispose());
    });
  });
}
