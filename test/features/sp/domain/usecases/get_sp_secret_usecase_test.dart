import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    as wallet_model;
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bb_mobile/features/sp/domain/usecases/get_sp_secret_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

class _WalletRepository extends Mock implements WalletRepository {}

class _Wallet extends Mock implements wallet_model.Wallet {}

void main() {
  test('refuses a watch-only source without fetching a default', () async {
    FakeSecureStoragePlatform().install();
    final secrets = Secrets(scratchDirectory: () async => '/tmp');
    final selected = _Wallet();
    when(() => selected.isBitcoin).thenReturn(true);
    when(() => selected.signsLocally).thenReturn(false);
    final repository = _WalletRepository();
    when(
      () => repository.getWallet('wallet'),
    ).thenAnswer((_) async => Ok(selected));

    final result = await GetSpSecretUsecase(
      walletRepository: repository,
      secrets: secrets,
    ).resolve(BitcoinNetwork.signet, walletId: 'wallet');

    expect(result, isA<Err<dynamic, SpFailure>>());
    verifyNever(
      () => repository.getWallets(onlyDefaults: true, onlyBitcoin: true),
    );
  });
}
