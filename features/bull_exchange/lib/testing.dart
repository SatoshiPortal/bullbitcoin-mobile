/// Presentation identifiers for route integration tests.
library;

import 'package:exchange/exchange.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'src/autobuy/domain/autobuy_failure.dart';
import 'src/autobuy/domain/autobuy_status.dart';
import 'src/autobuy/domain/usecases/get_autobuy_status_usecase.dart';
import 'src/autobuy/domain/usecases/set_autobuy_usecase.dart';
import 'src/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'src/default_wallets/presentation/default_wallets_cubit.dart';

export 'src/pay/domain/get_pay_order_usecase.dart' show GetPayOrderUsecase;
export 'src/pay/domain/pay_failure.dart';
export 'src/pay/presentation/pay_bloc.dart';
export 'src/pay/ui/screens/pay_receive_payment_screen.dart'
    show PayReceivePaymentScreen;
export 'src/pay/ui/screens/pay_send_payment_screen.dart'
    show PaySendPaymentScreen;
export 'src/payin/exchange_payin_ui.dart' show ExchangePayinUi;
export 'src/payin/payin_account.dart' show PayinAccount;
export 'src/payin/payin_wallets.dart' show PayinWallets;
export 'src/sell/domain/sell_failure.dart';
export 'src/sell/domain/sell_payin_source.dart' show SellPayinSource;
export 'src/sell/domain/usecases/get_sell_confidential_sepa_availability_usecase.dart'
    show GetSellConfidentialSepaAvailabilityUsecase;
export 'src/sell/domain/usecases/load_sell_context_usecase.dart'
    show LoadSellContextUsecase;
export 'src/sell/presentation/sell_bloc.dart';
export 'src/sell/presentation/sell_payout_cubit.dart' show SellPayoutCubit;
export 'src/sell/ui/screens/sell_payout_method_screen.dart'
    show SellPayoutMethodScreen;
export 'src/sell/ui/screens/sell_receive_payment_screen.dart'
    show SellReceivePaymentScreen;
export 'src/sell/ui/screens/sell_send_payment_screen.dart'
    show SellSendPaymentScreen;
export 'src/sell/ui/sell_router.dart' show SellRouter;
export 'src/ui/screens/exchange_landing_screen.dart' show ExchangeLandingScreen;
export 'src/auth/exchange_auth_screen.dart' show ExchangeAuthScreen;
export 'src/auth/exchange_exit_on_back.dart' show ExchangeExitOnBack;
export 'src/dashboard/exchange_home_screen.dart' show ExchangeHomeScreen;
export 'src/dashboard/exchange_home_actions.dart' show ExchangeHomeActions;
export 'src/dashboard/announcement_banner.dart' show AnnouncementBanner;
export 'src/settings/ui/widgets/exchange_account_sheets.dart'
    show ExchangeAccountSheets;
export 'src/session/exchange_cubit.dart' show ExchangeCubit;
export 'src/session/exchange_state.dart' show ExchangeState;
export 'src/settings/ui/screens/exchange_settings_screen.dart'
    show ExchangeSettingsScreen;
export 'src/settings/ui/screens/security_navigation.dart'
    show allowsSecurityNavigation;
export 'src/settings/ui/widgets/not_logged_in_bottom_sheet.dart'
    show NotLoggedInBottomSheet;

export 'src/buy/domain/accelerate_buy_order_usecase.dart';
export 'src/buy/domain/buy_failure.dart';
export 'src/buy/domain/cancel_abandoned_buy_payjoin_usecase.dart';
export 'src/buy/domain/confirm_buy_order_usecase.dart';
export 'src/buy/domain/create_buy_order_usecase.dart';
export 'src/buy/domain/get_buy_payjoin_enabled_usecase.dart';
export 'src/buy/domain/label_completed_buy_order_usecase.dart';
export 'src/buy/domain/load_buy_context_usecase.dart';
export 'src/buy/domain/refresh_buy_order_usecase.dart';
export 'src/buy/domain/sync_buy_receipt_usecase.dart';
export 'src/buy/domain/validate_buy_destination_usecase.dart';
export 'src/buy/presentation/buy_bloc.dart';
export 'src/buy/presentation/buy_failure_l10n.dart';
export 'src/buy/ui/screens/buy_accelerate_screen.dart';
export 'src/buy/ui/screens/buy_accelerate_success_screen.dart';
export 'src/buy/ui/screens/buy_confirm_screen.dart';
export 'src/buy/ui/screens/buy_input_screen.dart';
export 'src/buy/ui/screens/buy_success_screen.dart';
export 'src/buy/ui/widgets/buy_amount_input_fields.dart';
export 'src/dca/domain/dca_failure.dart';
export 'src/dca/domain/usecases/set_dca_usecase.dart';
export 'src/dca/domain/usecases/start_dca_usecase.dart';
export 'src/dca/presentation/dca_bloc.dart';
export 'src/dca/ui/screens/dca_success_screen.dart';
export 'src/buy/ui/buy_router.dart' show BuyRouter;
export 'src/exchange_payout_wallets.dart' show ExchangePayoutWallets;

Future<Result<AutoBuyStatus, AutoBuyFailure>> autoBuyStatusForTesting(
  Exchange exchange,
) => GetAutoBuyStatusUsecase(exchange).execute();

Future<Result<void, AutoBuyFailure>> disableAutoBuyForTesting(
  Exchange exchange,
  Preferences preferences,
) => SetAutoBuyUsecase(preferences, exchange).execute(enabled: false);

DefaultWalletsCubit defaultWalletsCubitForTesting({
  required Exchange exchange,
  required Future<String?> Function(WalletAddressType, String) validate,
}) => DefaultWalletsCubit(
  exchange: exchange,
  validateDestination: ValidateDefaultWalletDestinationUsecase(validate),
);
