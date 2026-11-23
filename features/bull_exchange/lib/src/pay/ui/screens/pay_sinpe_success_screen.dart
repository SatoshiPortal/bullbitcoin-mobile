import 'package:bull_exchange/src/exchange_landing_navigation.dart';

import 'dart:async';

import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/pay/presentation/pay_bloc.dart';
import 'package:bull_exchange/src/pay/ui/widgets/sinpe_receipt_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScrollableColumn, Gap, BullTypographyX;
import 'package:go_router/go_router.dart';

class PaySinpeSuccessScreen extends StatefulWidget {
  const PaySinpeSuccessScreen({super.key});

  @override
  State<PaySinpeSuccessScreen> createState() => _PaySinpeSuccessScreenState();
}

class _PaySinpeSuccessScreenState extends State<PaySinpeSuccessScreen> {
  Timer? _pollingTimer;

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

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (PayBloc bloc) => bloc.state is PaySuccessState
          ? (bloc.state as PaySuccessState).payOrder
          : null,
    );

    if (order == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        context.goNamed(BullExchangeNavigation.dashboardName);
      },
      child: Scaffold(
        backgroundColor: context.appColors.secondaryFixed,
        appBar: AppBar(
          title: Text(
            context.loc.payOrderDetails,
            style: context.bullType.subtitle
                .copyWith(fontWeight: FontWeight.w500)
                .copyWith(color: context.appColors.outline),
          ),
          backgroundColor: context.appColors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              tooltip: context.loc.closeDialogButton,
              icon: const Icon(Icons.close),
              onPressed: () {
                context.goNamed(BullExchangeNavigation.dashboardName);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: BullScrollableColumn(
            children: [
              SinpeReceiptCard(order: order),
              const Gap(24),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: BullButton.secondary(
                  label: context.loc.payDone,
                  onPressed: () {
                    context.goNamed(BullExchangeNavigation.dashboardName);
                  },
                ),
              ),
              const Gap(24),
            ],
          ),
        ),
      ),
    );
  }
}
