import 'dart:async';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/pay_router.dart';
import 'package:bb_mobile/features/transactions/ui/transactions_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
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
      final order =
          context.read<PayBloc>().state is PaySuccessState
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

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (PayBloc bloc) =>
          bloc.state is PaySuccessState
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
            context.goNamed(
              PayRoute.paySinpeSuccess.name,
              extra: context.read<PayBloc>(),
            );
          }
          // Handle other recipient types
          else if (!_isSinpeMovilOrder(currentOrder) &&
              currentOrder.payoutStatus == OrderPayoutStatus.completed) {
            _stopPolling();
            context.goNamed(
              PayRoute.payPaymentCompleted.name,
              extra: context.read<PayBloc>(),
            );
          }
        }
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return; // Don't allow back navigation

          context.goNamed(ExchangeRoute.exchangeHome.name);
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(context.loc.payTitle),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  context.goNamed(ExchangeRoute.exchangeHome.name);
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Gif(
                    image: AssetImage(Assets.animations.cubesLoading.path),
                    autostart: Autostart.loop,
                    height: 100,
                    width: 100,
                  ),
                  const Gap(20),
                  Text(
                    context.loc.payPaymentInProgress,
                    style: context.font.titleLarge,
                  ),
                  const Gap(10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      context.loc.payPaymentInProgressDescription,
                      style: context.font.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (order != null)
                    BBButton.big(
                      label: context.loc.payViewDetails,
                      onPressed: () {
                        context.pushNamed(
                          TransactionsRoute.orderTransactionDetails.name,
                          pathParameters: {'orderId': order.orderId},
                        );
                      },
                      bgColor: context.appColors.secondary,
                      textColor: context.appColors.onPrimary,
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
