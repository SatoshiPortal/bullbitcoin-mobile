import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/complete_exchange_authentication_usecase.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_web_settings_usecase.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bull_exchange/bull_exchange.dart';

import 'dart:async';

import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:exchange/exchange.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';

abstract final class ExchangeScope {
  static final ExchangeAuthHost authHost = (
    loadConfiguration: () => locator<GetExchangeWebSettingsUsecase>().execute(),
    authenticate:
        (
          context,
          evaluateJavaScript, {
          required isTestnet,
          required isCurrent,
        }) => ExchangeSessionScope.finishAuthentication(
          context,
          locator<CompleteExchangeAuthenticationUsecase>(
            param1: evaluateJavaScript,
            param2: (isTestnet: isTestnet, isOpen: isCurrent),
          ).execute,
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

  /// A session that ends while access stays enabled can sign in again.
  static bool isEnabled(BuildContext context) =>
      locator<ExchangeFacade>().currentAccess is ExchangeAccessEnabled;
}

class ExchangeSessionBuilder extends StatelessWidget {
  final Widget Function(BuildContext, bool isLoggedIn) builder;

  const ExchangeSessionBuilder({required this.builder, super.key});

  @override
  Widget build(BuildContext context) => ExchangeAccessBuilder(
    builder: (context, access) => builder(context, _signedIn(access)),
  );
}

class ExchangeSessionListener extends StatelessWidget {
  final Widget child;
  final bool Function(bool wasLoggedIn, bool isLoggedIn)? listenWhen;
  final void Function(BuildContext, bool isLoggedIn) listener;

  const ExchangeSessionListener({
    required this.child,
    required this.listener,
    this.listenWhen,
    super.key,
  });

  @override
  Widget build(BuildContext context) => _SessionChanges(owner: this);
}

bool _signedIn(ExchangeAccess access) =>
    access is ExchangeAccessEnabled &&
    access.session == ExchangeAccessSession.signedIn;

class _SessionChanges extends StatefulWidget {
  const _SessionChanges({required this.owner});
  final ExchangeSessionListener owner;
  @override
  State<_SessionChanges> createState() => _SessionChangesState();
}

class _SessionChangesState extends State<_SessionChanges> {
  StreamSubscription<ExchangeAccess>? _subscription;
  @override
  void initState() {
    super.initState();
    final exchange = locator<ExchangeFacade>();
    var previous = _signedIn(exchange.currentAccess);
    _subscription = exchange.watchAccess().listen((access) {
      final current = _signedIn(access);
      final changed = current != previous;
      final notify =
          changed && (widget.owner.listenWhen?.call(previous, current) ?? true);
      previous = current;
      if (mounted && notify) widget.owner.listener(context, current);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.owner.child;
}

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
