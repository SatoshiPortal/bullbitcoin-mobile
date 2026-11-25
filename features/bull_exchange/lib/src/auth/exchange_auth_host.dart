import 'package:exchange/exchange.dart';

import '../exchange_failure_l10n.dart';
import '../session/exchange_session_scope.dart';
import 'exchange_auth_screen.dart';

/// Binds the authentication WebView to the opened [exchange] capability.
ExchangeAuthHost exchangeAuthHost(Exchange Function() exchange) => (
  loadConfiguration: () => exchange().loadWebPreferences(),
  authenticate:
      (context, evaluateJavaScript, {required isTestnet, required isCurrent}) =>
          ExchangeSessionScope.finishAuthentication(
            context,
            ({required isCurrent}) => exchange().authenticateWebSession(
              isTestnet: isTestnet,
              evaluateJavaScript: evaluateJavaScript,
              isCurrent: isCurrent,
            ),
            isCurrent: isCurrent,
          ),
  failureMessage: (context, failure) => failure.toTranslated(context),
  mainnetSignInUrl: Uri.parse(ExchangeDefaults.bbAuthUrl),
  testnetSignInUrl: Uri.parse(ExchangeDefaults.bbAuthTestUrl),
  returnUrl: Uri.parse(ExchangeDefaults.bbAppUrl),
  testnetKycUrl: Uri.parse(ExchangeDefaults.bbKycTestUrl),
  currentAccess: () => exchange().currentAccess,
  watchAccess: () => exchange().watchAccess(),
  accountSignedInChanges: ExchangeSessionScope.accountChanges,
  retryAccess: (_) async {
    final _ = await exchange().resolveAccess();
  },
);
