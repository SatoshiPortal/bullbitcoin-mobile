import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/scanning/public/qr_scanning.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullTypographyX;

/// Callback for the raw text detected from a QR code.
typedef OnScannedPaymentRequestCallback = void Function(String raw);

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
  String data = '';

  void _onScanned(String qr) {
    if (!mounted) return;
    data = qr;
    widget.onScannedPaymentRequest(qr);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      body: Stack(
        fit: .expand,
        children: [
          QrScannerWidget(onScanned: _onScanned),
          if (data.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: 24,
              right: 24,
              child: BullButton.secondary(
                iconData: Icons.check_circle,
                textStyle: context.bullType.caption,
                onPressed: () {},
                label: data.length > 30
                    ? '${data.substring(0, 10)}…${data.substring(data.length - 10)}'
                    : data,
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
