import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/pay/presentation/pay_bloc.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
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

  String _formatSinpePhoneNumber(String? phoneNumber) {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      return context.loc.payNotAvailable;
    }

    // Remove any existing formatting
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add +506 prefix
    final String formattedNumber = '+506$cleanNumber';

    // Add dashes every 4 digits after the prefix
    if (cleanNumber.length >= 4) {
      const String prefix = '+506';
      final String number = cleanNumber;
      final StringBuffer formatted = StringBuffer(prefix);

      for (int i = 0; i < number.length; i += 4) {
        final int end = (i + 4 < number.length) ? i + 4 : number.length;
        formatted.write('-${number.substring(i, end)}');
      }

      return formatted.toString();
    }

    return formattedNumber;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
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

  @override
  Widget build(BuildContext context) {
    final order = context.select(
      (PayBloc bloc) =>
          bloc.state is PaySuccessState
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
              Card(
                margin: const EdgeInsets.all(24.0),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: .min,
                    children: [
                      Gif(
                        image: AssetImage(Assets.animations.successTick.path),
                        autostart: Autostart.once,
                        width: 150,
                        height: 150,
                      ),
                      Text(
                        context.loc.paySinpeEnviado,
                        style: context.font.headlineLarge?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(16),
                      Text(
                        context.loc.paySinpeMonto,
                        style: context.font.bodyMedium,
                      ),
                      const Gap(4),
                      Text(
                        '${order.payoutAmount.toStringAsFixed(2)} ${order.payoutCurrency}',
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        context.loc.paySinpeNumeroOrden,
                        style: context.font.bodyMedium,
                      ),
                      const Gap(4),
                      Text(
                        order.orderNumber.toString(),
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        context.loc.paySinpeNumeroComprobante,
                        style: context.font.bodyMedium,
                      ),
                      const Gap(4),
                      Text(
                        order.referenceNumber ?? context.loc.payNotAvailable,
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        context.loc.paySinpeBeneficiario,
                        style: context.font.bodyMedium,
                      ),
                      const Gap(4),
                      Text(
                        order.beneficiaryName ?? context.loc.payNotAvailable,
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        _formatSinpePhoneNumber(order.beneficiaryAccountNumber),
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(8),
                      Text(
                        context.loc.paySinpeOrigen,
                        style: context.font.bodyMedium,
                      ),
                      const Gap(4),
                      Text(
                        order.originName ?? context.loc.payNotAvailable,
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        order.originCedula ?? context.loc.payNotAvailable,
                        style: context.font.headlineSmall?.copyWith(
                          color: context.appColors.secondary,
                          fontWeight: .bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
