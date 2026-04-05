import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/features/pay/ui/widgets/sinpe_receipt_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
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

        context.goNamed(ExchangeRoute.exchangeHome.name);
      },
      child: Scaffold(
        backgroundColor: context.appColors.secondaryFixed,
        appBar: AppBar(
          title: Text(
            context.loc.payOrderDetails,
            style: context.font.headlineMedium?.copyWith(
              color: context.appColors.outline,
            ),
          ),
          backgroundColor: context.appColors.transparent,
          elevation: 0,
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
          child: ScrollableColumn(
            children: [
              SinpeReceiptCard(order: order),
              const Gap(24),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: BBButton.big(
                  label: context.loc.payDone,
                  onPressed: () {
                    context.goNamed(ExchangeRoute.exchangeHome.name);
                  },
                  bgColor: context.appColors.secondary,
                  textColor: context.appColors.onPrimary,
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
