import 'package:bb_mobile/core_deprecated/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core_deprecated/exchange/domain/repositories/exchange_order_repository.dart';
import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';

class SetDcaUsecase {
  final ExchangeOrderRepository _mainnetDcaRepository;
  final ExchangeOrderRepository _testnetDcaRepository;
  // TODO: Don't use the repositories of other domains directly, but use reduced
  // interfaces for each domain just for what is needed from them in the DCA context/domain
  final WalletRepository _wallet;
  final SettingsRepository _settingsRepository;
  final WalletAddressRepository _walletAddressRepository;

  SetDcaUsecase({
    required ExchangeOrderRepository mainnetExchangeOrderRepository,
    required ExchangeOrderRepository testnetExchangeOrderRepository,
    required WalletRepository wallet,
    required SettingsRepository settingsRepository,
    required WalletAddressRepository walletAddressRepository,
  }) : _mainnetDcaRepository = mainnetExchangeOrderRepository,
       _testnetDcaRepository = testnetExchangeOrderRepository,
       _wallet = wallet,
       _settingsRepository = settingsRepository,
       _walletAddressRepository = walletAddressRepository;

  Future<Dca> execute({
    required double amount,
    required FiatCurrency currency,
    required DcaBuyFrequency frequency,
    required DcaNetwork network,
    String? lightningAddress,
  }) async {
    final settings = await _settingsRepository.fetch();
    final environment = settings.environment;
    String address;
    if (network == DcaNetwork.lightning) {
      if (lightningAddress == null || lightningAddress.isEmpty) {
        throw Exception(
          'Lightning address is required for Lightning network DCA',
        );
      }
      address = lightningAddress;
    } else {
      final wallets = await _wallet.getWallets(
        environment: environment,
        onlyDefaults: true,
        onlyBitcoin: network == DcaNetwork.bitcoin,
        onlyLiquid: network == DcaNetwork.liquid,
      );

      if (wallets.isEmpty) {
        throw Exception('No default wallet found');
      }

      final defaultWallet = wallets.first;
      final walletAddress = await _walletAddressRepository
          .generateNewReceiveAddress(walletId: defaultWallet.id);
      address = walletAddress.address;
    }

    return environment.isMainnet
        ? _mainnetDcaRepository.createDca(
          amount: amount,
          currency: currency,
          frequency: frequency,
          network: network,
          address: address,
        )
        : _testnetDcaRepository.createDca(
          amount: amount,
          currency: currency,
          frequency: frequency,
          network: network,
          address: address,
        );
  }
}
