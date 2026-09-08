import 'package:bb_mobile/core/exchange/domain/usecases/convert_sats_to_currency_amount_usecase.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_available_currencies_usecase.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_address_at_index_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_receive_address_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/watch_wallet_transaction_by_address_usecase.dart';
import 'package:bb_mobile/features/labels/labels_facade.dart';
import 'package:bb_mobile/features/receive/domain/usecases/broadcast_original_transaction_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_payjoin_policy_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/receive_with_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/create_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/convert_receive_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/fetch_receive_note_suggestions_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_address_at_index_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_currencies_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_settings_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/get_receive_wallets_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/load_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/prepare_receive_address_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/save_receive_address_label_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/set_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_payjoin_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_order_swap_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_min_amount_usecase.dart';
import 'package:bb_mobile/features/receive/domain/usecases/watch_receive_payjoin_enabled_usecase.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:bb_mobile/features/swap/public/swap_facade.dart';
import 'package:get_it/get_it.dart';

class ReceiveLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<ReceiveWithPayjoinUsecase>(
      () => ReceiveWithPayjoinUsecase(locator<PayjoinReceiver>()),
    );
    locator.registerFactory<BroadcastOriginalTransactionUsecase>(
      () => BroadcastOriginalTransactionUsecase(locator<PayjoinSender>()),
    );
    locator.registerFactory<WatchPayjoinUsecase>(
      () => WatchPayjoinUsecase(locator<PayjoinSessions>()),
    );
    locator.registerFactory<GetReceivePayjoinPolicyUsecase>(
      () => GetReceivePayjoinPolicyUsecase(locator<SettingsFacade>()),
    );
    locator.registerFactory<WatchReceivePayjoinEnabledUsecase>(
      () => WatchReceivePayjoinEnabledUsecase(locator<SettingsFacade>()),
    );
    locator.registerFactory<CreateReceiveOrderSwapUsecase>(
      () => CreateReceiveOrderSwapUsecase(
        locator<SwapFacade>(),
        locator<GetReceiveAddressUsecase>(),
      ),
    );
    locator.registerFactory<SetReceivePayjoinEnabledUsecase>(
      () => SetReceivePayjoinEnabledUsecase(
        settingsFacade: locator<SettingsFacade>(),
      ),
    );
    locator.registerFactory<WatchReceivePayjoinMinAmountUsecase>(
      () => WatchReceivePayjoinMinAmountUsecase(
        settingsFacade: locator<SettingsFacade>(),
      ),
    );
    locator.registerFactory<WatchReceiveOrderSwapUsecase>(
      () => WatchReceiveOrderSwapUsecase(locator<SwapFacade>()),
    );

    // Receive-owned boundaries for collaborators that still throw: the shared
    // core use-cases and the labels feature's facade. They exist so the bloc
    // holds Results and this feature's failures only — see AGENTS.md rule #11
    // (the feature use-case is the try/catch boundary when the underlying
    // repository is shared and still throws) and rule #4 (a bloc never calls
    // another feature's facade directly).
    locator.registerFactory<GetReceiveWalletsUsecase>(
      () => GetReceiveWalletsUsecase(locator<GetWalletsUsecase>()),
    );
    locator.registerFactory<GetReceiveSettingsUsecase>(
      () => GetReceiveSettingsUsecase(locator<GetSettingsUsecase>()),
    );
    locator.registerFactory<GetReceiveCurrenciesUsecase>(
      () =>
          GetReceiveCurrenciesUsecase(locator<GetAvailableCurrenciesUsecase>()),
    );
    locator.registerFactory<ConvertReceiveAmountUsecase>(
      () => ConvertReceiveAmountUsecase(
        locator<ConvertSatsToCurrencyAmountUsecase>(),
      ),
    );
    locator.registerFactory<PrepareReceiveAddressUsecase>(
      () => PrepareReceiveAddressUsecase(locator<GetReceiveAddressUsecase>()),
    );
    locator.registerFactory<GetReceiveAddressAtIndexUsecase>(
      () =>
          GetReceiveAddressAtIndexUsecase(locator<GetAddressAtIndexUsecase>()),
    );
    locator.registerFactory<LoadReceiveAddressLabelUsecase>(
      () => LoadReceiveAddressLabelUsecase(locator<LabelsFacade>()),
    );
    locator.registerFactory<SaveReceiveAddressLabelUsecase>(
      () => SaveReceiveAddressLabelUsecase(locator<LabelsFacade>()),
    );
    locator.registerFactory<FetchReceiveNoteSuggestionsUsecase>(
      () => FetchReceiveNoteSuggestionsUsecase(locator<LabelsFacade>()),
    );

    // Bloc
    locator.registerFactoryParam<ReceiveBloc, Wallet?, void>(
      (wallet, _) => ReceiveBloc(
        getReceiveWalletsUsecase: locator<GetReceiveWalletsUsecase>(),
        getReceiveCurrenciesUsecase: locator<GetReceiveCurrenciesUsecase>(),
        getReceiveSettingsUsecase: locator<GetReceiveSettingsUsecase>(),
        convertReceiveAmountUsecase: locator<ConvertReceiveAmountUsecase>(),
        prepareReceiveAddressUsecase: locator<PrepareReceiveAddressUsecase>(),
        getReceiveAddressAtIndexUsecase:
            locator<GetReceiveAddressAtIndexUsecase>(),
        createReceiveOrderSwapUsecase: locator<CreateReceiveOrderSwapUsecase>(),
        receiveWithPayjoinUsecase: locator<ReceiveWithPayjoinUsecase>(),
        broadcastOriginalTransactionUsecase:
            locator<BroadcastOriginalTransactionUsecase>(),
        watchPayjoinUsecase: locator<WatchPayjoinUsecase>(),
        watchWalletTransactionByAddressUsecase:
            locator<WatchWalletTransactionByAddressUsecase>(),
        watchReceiveOrderSwapUsecase: locator<WatchReceiveOrderSwapUsecase>(),
        loadReceiveAddressLabelUsecase:
            locator<LoadReceiveAddressLabelUsecase>(),
        saveReceiveAddressLabelUsecase:
            locator<SaveReceiveAddressLabelUsecase>(),
        fetchReceiveNoteSuggestionsUsecase:
            locator<FetchReceiveNoteSuggestionsUsecase>(),
        watchReceivePayjoinEnabledUsecase:
            locator<WatchReceivePayjoinEnabledUsecase>(),
        watchReceivePayjoinMinAmountUsecase:
            locator<WatchReceivePayjoinMinAmountUsecase>(),
        getReceivePayjoinPolicyUsecase:
            locator<GetReceivePayjoinPolicyUsecase>(),
        setReceivePayjoinEnabledUsecase:
            locator<SetReceivePayjoinEnabledUsecase>(),
        wallet: wallet,
      ),
    );
  }
}
