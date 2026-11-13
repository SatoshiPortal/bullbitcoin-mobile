import 'dart:async';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeScope extends StatelessWidget {
  final Widget child;

  const ExchangeScope({required this.child, super.key});

  static bool isLoggedIn(BuildContext context) =>
      _signedIn(locator<ExchangeFacade>().currentAccess);

  static Future<void> refreshSession(BuildContext context) =>
      context.read<ExchangeCubit>().fetchUserSummary();

  static Future<void> reconnectNotifications(BuildContext context) =>
      context.read<ExchangeCubit>().reconnectWebSocket();

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => locator<ExchangeCubit>(),
    child: ExchangeListener(child: child),
  );
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
