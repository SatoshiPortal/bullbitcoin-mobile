import 'dart:async';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
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
    if (phoneNumber == null || phoneNumber.isEmpty) return 'N/A';

    // Remove any existing formatting
    final String cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');

    // Add +501 prefix
    final String formattedNumber = '+501$cleanNumber';

    // Add dashes every 4 digits after the prefix
    if (cleanNumber.length >= 4) {
      const String prefix = '+501';
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
        backgroundColor: context.colour.secondaryFixed,
        appBar: AppBar(
          title: BBText(
            'Order Details',
            style: context.font.headlineMedium?.copyWith(
              color: context.colour.outline,
            ),
          ),
          backgroundColor: Colors.transparent,
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
          child: Center(
            child: Card(
              margin: const EdgeInsets.all(24.0),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Gif(
                      image: AssetImage(Assets.animations.successTick.path),
                      autostart: Autostart.once,
                      width: 150,
                      height: 150,
                    ),
                    BBText(
                      'SINPE ENVIADO!',
                      style: context.font.headlineLarge?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(16),
                    BBText(
                      '${order.payoutAmount.toStringAsFixed(2)} ${order.payoutCurrency}',
                      style: context.font.headlineSmall?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(8),
                    BBText(
                      order.beneficiaryName ?? 'N/A',
                      style: context.font.headlineSmall?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Gap(8),
                    BBText(
                      _formatSinpePhoneNumber(order.beneficiaryAccountNumber),
                      style: context.font.headlineSmall?.copyWith(
                        color: context.colour.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // const Gap(8),
                    // BBText(
                    //   'COMPROBANTE:',
                    //   style: context.font.headlineSmall?.copyWith(
                    //     color: context.colour.secondary,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    // const Gap(4),
                    // BBText(
                    //   order.orderId,
                    //   style: context.font.bodyMedium?.copyWith(
                    //     color: context.colour.secondary,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                    const Gap(32),
                    SizedBox(
                      width: double.infinity,
                      child: BBButton.big(
                        label: 'Done',
                        onPressed: () {
                          context.goNamed(ExchangeRoute.exchangeHome.name);
                        },
                        bgColor: context.colour.secondary,
                        textColor: context.colour.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
