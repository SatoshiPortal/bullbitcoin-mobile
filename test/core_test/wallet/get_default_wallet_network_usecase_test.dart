import 'package:bb_mobile/features/wallet/domain/usecases/get_default_wallet_network_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _WalletReader extends Mock implements GetWalletsUsecase {}

class _Wallet extends Mock implements legacy.Wallet {}

void main() {
  test('uses the default wallet environment across chains', () async {
    final reader = _WalletReader();
    final first = _Wallet();
    final defaultWallet = _Wallet();
    when(() => first.isDefault).thenReturn(false);
    when(() => defaultWallet.isDefault).thenReturn(true);
    when(() => defaultWallet.network).thenReturn(legacy.Network.liquidRegtest);
    when(reader.execute).thenAnswer((_) async => Ok([first, defaultWallet]));

    expect(
      await GetDefaultWalletNetworkUsecase(reader).execute(),
      isA<Ok<NetworkEnv?, WalletFailure>>().having(
        (result) => result.value,
        'network',
        NetworkEnv.regtest,
      ),
    );
  });

  test(
    'reports a missing wallet without treating a storage failure as absence',
    () async {
      final reader = _WalletReader();
      final usecase = GetDefaultWalletNetworkUsecase(reader);
      when(reader.execute)
          .thenAnswer((_) async => const Err(NoWalletsFoundFailure()));
      expect(
        await usecase.execute(),
        isA<Ok<NetworkEnv?, WalletFailure>>().having(
          (result) => result.value,
          'network',
          isNull,
        ),
      );

      const storageFailure = WalletStorageFailure('read failed');
      when(reader.execute).thenAnswer((_) async => const Err(storageFailure));
      expect(
        await usecase.execute(),
        isA<Err<NetworkEnv?, WalletFailure>>().having(
          (result) => result.failure,
          'failure',
          same(storageFailure),
        ),
      );
    },
  );
}
