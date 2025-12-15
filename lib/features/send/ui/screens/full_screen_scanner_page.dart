import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/payment_request.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/qr_scanner_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Callback for when a payment request is detected from a QR code
typedef OnScannedPaymentRequestCallback =
    void Function((String, PaymentRequest?) data);

class FullScreenScannerPage extends StatefulWidget {
  final OnScannedPaymentRequestCallback onScannedPaymentRequest;

  const FullScreenScannerPage({
    super.key,
    required this.onScannedPaymentRequest,
  });

  @override
  State<FullScreenScannerPage> createState() => _FullScreenScannerState();
}

class _FullScreenScannerState extends State<FullScreenScannerPage> {
  (String, PaymentRequest?) data = ('', null);

  Future<void> _onScanned(String qr) async {
    if (!mounted) return;

    try {
      final pr = await PaymentRequest.parse(qr);
      data = (qr, pr);
      widget.onScannedPaymentRequest(data);
      if (mounted) context.pop();
    } catch (e) {
      data = (qr, null);
      widget.onScannedPaymentRequest(data);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      body: Stack(
        fit: .expand,
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
