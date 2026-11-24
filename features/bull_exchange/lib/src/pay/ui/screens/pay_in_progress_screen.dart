import 'package:bull_exchange/src/payin/exchange_payin_ui.dart';
import 'package:bull_exchange/src/exchange_landing_navigation.dart';

import 'dart:async';

import 'package:exchange/exchange.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/src/pay/ui/pay_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullLoader, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class PayInProgressScreen extends StatefulWidget {
  const PayInProgressScreen({super.key});

  @override
  State<PayInProgressScreen> createState() => _PayInProgressScreenState();
}

class _PayInProgressScreenState extends State<PayInProgressScreen> {
  Timer? _pollingTimer;
  bool _hasStartedPolling = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  bool _isSinpeMovilOrder(FiatPaymentOrder order) {
    return order.payoutMethod == OrderPaymentMethod.sinpe &&
        order.payoutCurrency == 'CRC';
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _hasStartedPolling = true;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      final order = context.read<PayBloc>().state is PaySuccessState
          ? (context.read<PayBloc>().state as PaySuccessState).payOrder
          : null;

      if (order != null) {
        context.read<PayBloc>().add(
          PayEvent.updateOrderStatus(orderId: order.orderId),
        );
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// The copy follows the polled order: once the payin is confirmed onchain the
  /// message says so, instead of asking the user to keep waiting for a
  /// confirmation that already happened.
  String _description(BuildContext context, FiatPaymentOrder order) {
    final amount = order.payoutAmountToDisplay;
    final recipient = order.recipientToDisplay ?? context.loc.payNotAvailable;

    return order.isPayinCompleted
        ? context.loc.payPaymentPayinConfirmedDescriptionDetails(
            amount,
            recipient,
          )
        : context.loc.payPaymentInProgressDescriptionDetails(amount, recipient);
  }

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (PayBloc bloc) => bloc.state is PaySuccessState
          ? (bloc.state as PaySuccessState).payOrder
          : null,
    );

    return BlocListener<PayBloc, PayState>(
      listener: (context, state) {
        if (state is PaySuccessState && _hasStartedPolling) {
          final currentOrder = state.payOrder;

          // Handle SINPE móvil orders
          if (_isSinpeMovilOrder(currentOrder) &&
              currentOrder.payoutStatus == OrderPayoutStatus.completed) {
            _stopPolling();
            context.goNamed(PayRoute.paySinpeSuccess.name);
          }
          // Handle other recipient types
          else if (!_isSinpeMovilOrder(currentOrder) &&
              currentOrder.payoutStatus == OrderPayoutStatus.completed) {
            _stopPolling();
            context.goNamed(PayRoute.payPaymentCompleted.name);
          }
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return; // Don't allow back navigation

          context.goNamed(BullExchangeNavigation.dashboardName);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.payTitle),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  context.goNamed(BullExchangeNavigation.dashboardName);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: .center,
                children: [
                  const BullLoader.large(),
                  const Gap(20),
                  Text(
                    context.loc.payPaymentInProgress,
                    style: context.bullType.title,
                  ),
                  if (order != null) ...[
                    const Gap(10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Text(
                        _description(context, order),
                        style: context.bullType.body,
                        textAlign: .center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: .min,
                children: [
                  if (order != null)
                    BullButton.secondary(
                      label: context.loc.payViewDetails,
                      onPressed: () {
                        context.read<ExchangePayinUi>().openOrder(
                          context,
                          order.orderId,
                          returnToExchange: false,
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
