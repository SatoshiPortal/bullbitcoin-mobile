import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_default_wallet_xprv_port.dart';
import 'package:bb_mobile/features/lightning_address/domain/lightning_address_error.dart';

class DefaultWalletXprvAdapter
    implements LightningAddressDefaultWalletXprvPort {
  final GetSettingsUsecase _getSettings;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  const DefaultWalletXprvAdapter({
    required this._getSettings,
    required this._walletRepository,
    required this._seedRepository,
  });

  @override
  Future<String> deriveDefaultWalletXprv() async {
    final settings = await _getSettings.execute();
    final wallets = await _walletRepository.getWallets(
      environment: settings.environment,
      onlyDefaults: true,
      onlyBitcoin: true,
    );
    if (wallets.isEmpty) {
      throw const LightningAddressException.localPreparationFailed(
        code: 'NoDefaultBitcoinWallet',
        retryable: false,
      );
    }
    // Fail loud if more than one default bitcoin wallet exists: the identity
    // is derived from THE default wallet, so an ambiguous set must not silently
    // bind to an arbitrary one. Matches the prepare path's `.single` (R2-P12b).
    final defaultWallet = wallets.single;
    final seed = await _seedRepository.get(defaultWallet.masterFingerprint);
    return Bip32Derivation.getXprvFromSeed(seed.bytes, defaultWallet.network);
  }
}
