/// Presentation identifiers for route integration tests.
library;

import 'package:exchange/exchange.dart';

import 'src/autobuy/presentation/autobuy_bloc.dart';
import 'src/autobuy/presentation/autobuy_flow.dart';
import 'src/default_wallets/domain/validate_default_wallet_destination_usecase.dart';
import 'src/default_wallets/presentation/default_wallets_bloc.dart';
import 'src/default_wallets/presentation/default_wallets_machine.dart';

export 'src/default_wallets/presentation/default_wallets_bloc.dart'
    show DefaultWalletsBloc;
export 'src/default_wallets/presentation/default_wallets_machine.dart';
export 'src/pay/presentation/pay_flow.dart';
export 'src/pay/presentation/pay_flow_bloc.dart';
export 'src/pay/ui/pay_flow_shell.dart' show payPagesFor;
export 'src/payin/exchange_payin_ui.dart' show ExchangePayinUi;
export 'src/payin/ui/payin_source_page.dart' show PayinSourcePage;
export 'src/sell/presentation/sell_flow.dart';
export 'src/sell/presentation/sell_flow_bloc.dart';
export 'src/sell/ui/sell_flow_shell.dart' show sellPagesFor;
export 'src/ui/screens/exchange_landing_screen.dart' show ExchangeLandingScreen;
export 'src/auth/exchange_auth_host.dart' show exchangeAuthHost;
export 'src/auth/exchange_auth_screen.dart' show ExchangeAuthScreen;
export 'src/auth/exchange_exit_on_back.dart' show ExchangeExitOnBack;
export 'src/dashboard/exchange_home_screen.dart' show ExchangeHomeScreen;
export 'src/dashboard/exchange_home_actions.dart' show ExchangeHomeActions;
export 'src/dashboard/announcement_banner.dart' show AnnouncementBanner;
export 'src/settings/ui/widgets/exchange_account_sheets.dart'
    show ExchangeAccountSheets;
export 'src/session/exchange_bloc.dart' show ExchangeBloc;
export 'src/session/exchange_event.dart';
export 'src/session/exchange_machine.dart' show transitionExchange;
export 'src/session/exchange_state.dart';
export 'src/settings/ui/screens/exchange_settings_screen.dart'
    show ExchangeSettingsScreen;
export 'src/settings/ui/screens/security_navigation.dart'
    show allowsSecurityNavigation;
export 'src/settings/ui/widgets/not_logged_in_bottom_sheet.dart'
    show NotLoggedInBottomSheet;

export 'src/exchange_payout_wallets.dart' show ExchangePayoutWallets;

export 'src/limit_orders/domain/entities/limit_order_amount_limits.dart';
export 'src/ui/exchange_route_guard.dart';
export 'src/support_chat/presentation/support_unread_bloc.dart'
    show SupportUnreadBloc;
export 'src/support_chat/presentation/support_unread_machine.dart'
    show SupportUnreadEvent, SupportUnreadState, UnreadSignedOut;

/// The AutoBuy flow's account load for [session].
Future<ExchangeRead<AutoBuyContext>> autoBuyContextForTesting(
  Exchange exchange,
  ExchangeSession session,
) => autoBuyCallsOf(exchange, session).loadContext();

Future<DefaultWalletsEvent> defaultWalletsEffectForTesting(
  DefaultWalletsEffect effect, {
  required Exchange exchange,
  required Future<String?> Function(BtcNetwork, String) validate,
}) => runDefaultWalletsEffect(
  effect,
  exchange: exchange,
  validateDestination: ValidateDefaultWalletDestinationUsecase(validate),
);
