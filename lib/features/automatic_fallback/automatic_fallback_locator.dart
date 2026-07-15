import 'package:bb_mobile/core/seed/data/repository/seed_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/data/bullnym_automatic_fallback_service_adapter.dart';
import 'package:bb_mobile/features/automatic_fallback/data/default_bitcoin_fallback_wallet_adapter.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_service_port.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_wallet_port.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/ensure_automatic_fallback_address_usecase.dart';
import 'package:bb_mobile/features/automatic_fallback/public/automatic_fallback_facade.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

class AutomaticFallbackLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<AutomaticFallbackWalletPort>(
      () => DefaultBitcoinFallbackWalletAdapter(
        getWallets: locator<GetWalletsUsecase>(),
        seeds: locator<SeedRepository>(),
        nostrIdentity: locator<NostrIdentityFacade>(),
        addresses: locator<WalletAddressRepository>(),
        bitcoinWallet: locator<BitcoinWalletRepository>(),
        labels: locator<LabelsFacade>(),
      ),
    );
    locator.registerFactory<AutomaticFallbackServicePort>(
      () => BullnymAutomaticFallbackServiceAdapter(
        bullnym: locator<BullnymFacade>(),
      ),
    );
    locator.registerFactory<EnsureAutomaticFallbackAddressUsecase>(
      () => EnsureAutomaticFallbackAddressUsecase(
        wallet: locator<AutomaticFallbackWalletPort>(),
        service: locator<AutomaticFallbackServicePort>(),
      ),
    );
    locator.registerFactory<AutomaticFallbackFacade>(
      () => AutomaticFallbackFacade.fromUsecase(
        locator<EnsureAutomaticFallbackAddressUsecase>(),
      ),
    );
  }
}
