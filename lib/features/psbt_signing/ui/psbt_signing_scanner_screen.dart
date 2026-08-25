import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';

class PsbtSigningScannerScreen extends StatefulWidget {
  const PsbtSigningScannerScreen({super.key});

  @override
  State<PsbtSigningScannerScreen> createState() =>
      _PsbtSigningScannerScreenState();
}

class _PsbtSigningScannerScreenState extends State<PsbtSigningScannerScreen> {
  var _processing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.secondaryFixedDim,
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(
            onScanned: _onScanned,
            resolution: ResolutionPreset.high,
            scanDelay: const Duration(milliseconds: 100),
          ),
          Positioned(
            bottom: MediaQuery.sizeOf(context).height * 0.02,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                tooltip: context.loc.closeDialogButton,
                onPressed: context.pop,
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

  void _onScanned(String payload) {
    if (_processing || !payload.startsWith('cHN')) return;
    _processing = true;
    if (mounted) context.pop(payload);
  }
}
