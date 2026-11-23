import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_exchange/bull_exchange.dart';

import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';

abstract final class ExchangeScope {
  static final ExchangeAuthHost authHost = (
    loadConfiguration: () => locator<Exchange>().loadWebPreferences(),
    authenticate:
        (
          context,
          evaluateJavaScript, {
          required isTestnet,
          required isCurrent,
        }) => ExchangeSessionScope.finishAuthentication(
          context,
          ({required isCurrent}) => locator<Exchange>().authenticateWebSession(
            isTestnet: isTestnet,
            evaluateJavaScript: evaluateJavaScript,
            isCurrent: isCurrent,
          ),
          isCurrent: isCurrent,
        ),
    failureMessage: (context, failure) => failure.toTranslated(context),
    mainnetSignInUrl: Uri.parse(ApiServiceConstants.bbAuthUrl),
    testnetSignInUrl: Uri.parse(ApiServiceConstants.bbAuthTestUrl),
    returnUrl: Uri.parse(ApiServiceConstants.bbAppUrl),
    testnetKycUrl: Uri.parse(ApiServiceConstants.bbKycTestUrl),
    currentAccess: () => locator<ExchangeFacade>().currentAccess,
    watchAccess: ExchangeScope.accessChanges,
    accountSignedInChanges: ExchangeSessionScope.accountChanges,
    retryAccess: (_) async {
      final _ = await locator<Exchange>().resolveAccess();
    },
  );

  static bool isLoggedIn(BuildContext context) =>
      _signedIn(locator<ExchangeFacade>().currentAccess);

  static Exchange exchange() => locator<Exchange>();

  static Preferences preferences() => locator<Preferences>();

  static ExchangeAccess currentAccess() =>
      locator<ExchangeFacade>().currentAccess;

  static Stream<ExchangeAccess> accessChanges() =>
      locator<ExchangeFacade>().watchAccess();

  static Stream<bool> signedInChanges() => accessChanges().map(_signedIn);
}

class ExchangeSessionBuilder extends StatelessWidget {
  final Widget Function(BuildContext, bool isLoggedIn) builder;

  const ExchangeSessionBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) => ExchangeAccessBuilder(
    builder: (context, access) => builder(context, _signedIn(access)),
  );
}

bool _signedIn(ExchangeAccess access) =>
    access is ExchangeAccessEnabled &&
    access.session == ExchangeAccessSession.signedIn;

/// Rebuilds account entry points as the access/session decision changes.
class ExchangeAccessBuilder extends StatelessWidget {
  const ExchangeAccessBuilder({required this.builder, super.key});

  final Widget Function(BuildContext, ExchangeAccess) builder;

  @override
  Widget build(BuildContext context) {
    final access = locator<ExchangeFacade>();
    return StreamBuilder<ExchangeAccess>(
      stream: access.watchAccess(),
      initialData: access.currentAccess,
      builder: (context, snapshot) =>
          builder(context, snapshot.data ?? access.currentAccess),
    );
  }
}
