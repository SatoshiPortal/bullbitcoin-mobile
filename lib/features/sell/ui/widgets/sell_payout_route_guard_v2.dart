import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/features/sell/presentation/bloc/sell_bloc.dart';
import 'package:bb_mobile/features/sell/ui/sell_router.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class SellPayoutRouteGuardV2 extends StatefulWidget {
  final bool hasValidArguments;
  final Widget child;

  const SellPayoutRouteGuardV2({
    required this.child,
    this.hasValidArguments = true,
    super.key,
  });

  @override
  State<SellPayoutRouteGuardV2> createState() => _SellPayoutRouteGuardV2State();
}

class _SellPayoutRouteGuardV2State extends State<SellPayoutRouteGuardV2> {
  bool _redirectScheduled = false;

  bool _canOpen(SellState state) =>
      widget.hasValidArguments &&
      state is! SellInitialState &&
      state is! SellAmountInputState &&
      state.fiatCurrency == FiatCurrency.eur;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SellBloc>().state;
    if (_canOpen(state)) return widget.child;
    if (!_redirectScheduled) {
      _redirectScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _redirectScheduled = false;
        final current = context.read<SellBloc>().state;
        if (_canOpen(current)) return;
        context.goNamed(
          current.toCleanWalletSelectionState == null
              ? SellRoute.sell.name
              : SellRoute.sellWalletSelection.name,
        );
      });
    }
    return const SizedBox.shrink();
  }
}
