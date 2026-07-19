import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_default_wallet_xprv_port.dart';

class GetPaidDefaultWalletXprvAdapter implements GetPaidDefaultWalletXprvPort {
  final GetSettingsUsecase _getSettings;
  final WalletRepository _walletRepository;
  final SeedRepository _seedRepository;

  const GetPaidDefaultWalletXprvAdapter({
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
      throw Exception('No default Bitcoin wallet');
    }
    final wallet = wallets.single;
    final seed = await _seedRepository.get(wallet.masterFingerprint);
    return Bip32Derivation.getXprvFromSeed(seed.bytes, wallet.network);
  }
}
