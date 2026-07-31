import 'package:bb_mobile/core/blockchain/domain/usecases/broadcast_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/fees/domain/get_network_fees_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/bitcoin_wallet_repository.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_address_repository.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/broadcast_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/build_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_own_change_addresses_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/get_sweep_fees_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/parse_sweep_address_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/preview_sweep_fees_usecase.dart';
import 'package:bb_mobile/features/sweep/domain/usecases/sign_sweep_psbt_usecase.dart';
import 'package:bb_mobile/features/sweep/presentation/sweep_cubit.dart';
import 'package:bb_mobile/features/sweep/ui/sweep_router.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:get_it/get_it.dart';

class SweepLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<GetSweepFeesUsecase>(
      () => GetSweepFeesUsecase(
        getNetworkFeesUsecase: locator<GetNetworkFeesUsecase>(),
      ),
    );
    locator.registerFactory<ParseSweepAddressUsecase>(
      () => const ParseSweepAddressUsecase(),
    );
    locator.registerFactory<GetOwnChangeAddressesUsecase>(
      () => GetOwnChangeAddressesUsecase(
        walletAddressRepository: locator<WalletAddressRepository>(),
      ),
    );
    locator.registerFactory<BuildSweepPsbtUsecase>(
      () => BuildSweepPsbtUsecase(
        bitcoinSendPort: locator<BitcoinWalletRepository>(),
        walletUtxoRepository: locator<WalletUtxoRepository>(),
        payjoinSessions: locator<PayjoinSessions>(),
      ),
    );
    locator.registerFactory<PreviewSweepFeesUsecase>(
      () => PreviewSweepFeesUsecase(
        buildSweepPsbtUsecase: locator<BuildSweepPsbtUsecase>(),
      ),
    );
    locator.registerFactory<SignSweepPsbtUsecase>(
      () => SignSweepPsbtUsecase(
        bitcoinWalletRepository: locator<BitcoinWalletRepository>(),
      ),
    );
    locator.registerFactory<BroadcastSweepPsbtUsecase>(
      () => BroadcastSweepPsbtUsecase(
        broadcastBitcoinTransactionUsecase:
            locator<BroadcastBitcoinTransactionUsecase>(),
      ),
    );

    // Cubit — built per route with the coins the Coins screen selected.
    locator.registerFactoryParam<SweepCubit, SweepArgs, void>(
      (args, _) => SweepCubit(
        walletId: args.wallet.id,
        network: args.wallet.network,
        inputs: args.inputs,
        getSweepFeesUsecase: locator<GetSweepFeesUsecase>(),
        previewSweepFeesUsecase: locator<PreviewSweepFeesUsecase>(),
        parseSweepAddressUsecase: locator<ParseSweepAddressUsecase>(),
        getOwnChangeAddressesUsecase: locator<GetOwnChangeAddressesUsecase>(),
        buildSweepPsbtUsecase: locator<BuildSweepPsbtUsecase>(),
        signSweepPsbtUsecase: locator<SignSweepPsbtUsecase>(),
        broadcastSweepPsbtUsecase: locator<BroadcastSweepPsbtUsecase>(),
        getWalletUsecase: locator<GetWalletUsecase>(),
        convertSatsToCurrencyAmountUsecase:
            locator<ConvertSatsToCurrencyAmountUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
  }
}
