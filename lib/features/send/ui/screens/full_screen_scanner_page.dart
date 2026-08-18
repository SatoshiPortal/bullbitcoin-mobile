import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart';

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
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      safeArea: false,
      padding: EdgeInsets.zero,
      child: Stack(
        fit: .expand,
        children: [
          QrScannerWidget(onScanned: _onScanned),
          if (data.$1.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: 24,
              right: 24,
              child: BullButton.secondary(
                iconData: Icons.check_circle,
                textStyle: context.font.labelMedium,
                onPressed: () {},
                label: data.$1.length > 30
                    ? '${data.$1.substring(0, 10)}…${data.$1.substring(data.$1.length - 10)}'
                    : data.$1,
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
