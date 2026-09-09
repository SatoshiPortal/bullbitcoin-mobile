import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockWalletRepository extends Mock implements WalletRepository {}

void main() {
  test(
    'hides retired wallets unless a monitoring caller requests them',
    () async {
      final settings = _MockSettingsRepository();
      final wallets = _MockWalletRepository();
      final visible = _wallet('visible');
      final hidden = _wallet('hidden', isHidden: true);
      when(() => settings.fetch()).thenAnswer(
        (_) async => const SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
      when(
        () => wallets.getWallets(environment: Environment.mainnet),
      ).thenAnswer((_) async => [visible, hidden]);
      final usecase = GetWalletsUsecase(
        walletRepository: wallets,
        settingsRepository: settings,
      );

      expect(await usecase.execute(), [visible]);
      expect(await usecase.execute(includeHidden: true), [visible, hidden]);
    },
  );
}

Wallet _wallet(String id, {bool isHidden = false}) => Wallet(
  origin: id,
  network: Network.bitcoinMainnet,
  isHidden: isHidden,
  signers: const [],
  scriptType: ScriptType.bip84,
  publicDescriptor: 'wpkh($id/<0;1>/*)',
  balanceSat: BigInt.zero,
);
