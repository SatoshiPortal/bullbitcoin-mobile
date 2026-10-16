import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/sync_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  for (final fullDiscovery in [false, true]) {
    test('forwards fullDiscovery=$fullDiscovery to the repository', () async {
      final repository = _MockWalletRepository();
      final wallet = _MockWallet();
      when(
        () => repository.sync(wallet, fullDiscovery: fullDiscovery),
      ).thenAnswer((_) async {});
      final usecase = SyncWalletUsecase(walletRepository: repository);

      await usecase.execute(wallet, fullDiscovery: fullDiscovery);

      verify(
        () => repository.sync(wallet, fullDiscovery: fullDiscovery),
      ).called(1);
    });
  }
}
