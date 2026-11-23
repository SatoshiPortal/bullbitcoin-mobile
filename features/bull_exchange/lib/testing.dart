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
export 'src/settings/ui/screens/exchange_settings_screen.dart'
    show ExchangeSettingsScreen;
export 'src/settings/ui/screens/security_navigation.dart'
    show allowsSecurityNavigation;
export 'src/settings/ui/widgets/not_logged_in_bottom_sheet.dart'
    show NotLoggedInBottomSheet;

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
