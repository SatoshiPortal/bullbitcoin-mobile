import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ExchangeScope extends StatelessWidget {
  final Widget child;

  const ExchangeScope({required this.child, super.key});

  static bool isLoggedIn(BuildContext context) =>
      context.read<ExchangeCubit>().state.hasUser;

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
  Widget build(BuildContext context) =>
      BlocSelector<ExchangeCubit, ExchangeState, bool>(
        selector: (state) => state.hasUser,
        builder: builder,
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
  Widget build(BuildContext context) =>
      BlocListener<ExchangeCubit, ExchangeState>(
        listenWhen: (previous, current) =>
            previous.hasUser != current.hasUser &&
            (listenWhen?.call(previous.hasUser, current.hasUser) ?? true),
        listener: (context, state) => listener(context, state.hasUser),
        child: child,
      );
}
