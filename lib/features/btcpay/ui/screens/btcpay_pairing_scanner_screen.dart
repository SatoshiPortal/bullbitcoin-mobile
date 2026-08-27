import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BtcpayPairingScannerScreen extends StatefulWidget {
  const BtcpayPairingScannerScreen({super.key});

  @override
  State<BtcpayPairingScannerScreen> createState() =>
      _BtcpayPairingScannerScreenState();
}

class _BtcpayPairingScannerScreenState
    extends State<BtcpayPairingScannerScreen> {
  bool _handled = false;

  void _onScanned(String value) {
    if (!mounted || _handled) return;
    final pairingCode = value.trim();
    if (pairingCode.isEmpty) return;
    _handled = true;
    context.pop(pairingCode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(onScanned: _onScanned),
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: IconButton(
                  tooltip: context.loc.cancelButton,
                  onPressed: context.mounted ? () => context.pop() : null,
                  icon: Icon(
                    CupertinoIcons.xmark_circle,
                    color: context.appColors.onPrimary,
                    size: 64,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
