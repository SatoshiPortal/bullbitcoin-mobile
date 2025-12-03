import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SwapQrScannerPage extends StatefulWidget {
  const SwapQrScannerPage({super.key});

  @override
  State<SwapQrScannerPage> createState() => _SwapQrScannerPageState();
}

class _SwapQrScannerPageState extends State<SwapQrScannerPage> {
  (String, PaymentRequest?) data = ('', null);

  Future<void> _onScanned(String qr) async {
    if (!mounted) return;

    try {
      final pr = await PaymentRequest.parse(qr);
      String address = '';
      if (pr.isBitcoinAddress) {
        address = (pr as BitcoinPaymentRequest).address;
      } else if (pr.isLiquidAddress) {
        address = (pr as LiquidPaymentRequest).address;
      } else if (pr.isBip21) {
        final bip21 = pr as Bip21PaymentRequest;
        address = bip21.address;
      } else {
        address = qr;
      }
      data = (address, pr);
      if (mounted) {
        context.pop(address);
      }
    } catch (e) {
      data = (qr, null);
      if (mounted) {
        context.pop(qr);
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(onScanned: _onScanned),
          if (data.$1.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: 24,
              right: 24,
              child: BBButton.big(
                iconData: Icons.check_circle,
                textStyle: context.font.labelMedium,
                textColor: context.appColors.onPrimary,
                onPressed: () {},
                label:
                    data.$1.length > 30
                        ? '${data.$1.substring(0, 10)}…${data.$1.substring(data.$1.length - 10)}'
                        : data.$1,
                bgColor: context.appColors.transparent,
              ),
            ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.02,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: context.mounted ? () => context.pop() : null,
                icon: Icon(
                  CupertinoIcons.xmark_circle,
                  color: context.appColors.onPrimary,
                  size: 64,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
