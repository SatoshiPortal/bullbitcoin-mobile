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

export 'src/limit_orders/domain/entities/limit_order_amount_limits.dart';
export 'src/limit_orders/domain/entities/limit_order_creation_context.dart';
export 'src/limit_orders/domain/limit_orders_failure.dart';
export 'src/limit_orders/domain/usecases/create_limit_order_usecase.dart';
export 'src/limit_orders/domain/usecases/get_limit_order_rate_usecase.dart';
export 'src/limit_orders/domain/usecases/load_limit_order_creation_usecase.dart';
export 'src/limit_orders/domain/usecases/resolve_wallet_address_usecase.dart';
export 'src/limit_orders/domain/usecases/validate_lightning_address_usecase.dart';
export 'src/limit_orders/presentation/create_limit_order_cubit.dart';
export 'src/limit_orders/presentation/create_limit_order_state.dart';

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
