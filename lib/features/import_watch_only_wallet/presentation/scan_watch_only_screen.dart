import 'package:signers/signers.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/features/scanning/public/qr_scanning.dart';
import 'package:wallet_import/wallet_import.dart';
import 'package:primitives/primitives.dart' show Ok;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullSnackBar, BullTypographyX;

class ScanWatchOnlyScreen extends StatefulWidget {
  final SignerDevice? signerDevice;

  const ScanWatchOnlyScreen({super.key, this.signerDevice});

  @override
  State<ScanWatchOnlyScreen> createState() => _ScanWatchOnlyScreenState();
}

class _ScanWatchOnlyScreenState extends State<ScanWatchOnlyScreen> {
  String _scanned = '';
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.overlay,
      body: Stack(
        fit: .expand,
        children: [
          QrScannerWidget(
            scanDelay: widget.signerDevice?.supportedQrType == QrType.urqr
                ? const Duration(milliseconds: 10)
                : const Duration(milliseconds: 50),
            resolution: ResolutionPreset.high,
            onScanned: (data) async {
              if (_handled) return;
              _handled = true;
              setState(() => _scanned = data);
              try {
                final watchOnly = await readWatchOnlyQr(
                  context,
                  data,
                  device: widget.signerDevice,
                );

                if (!context.mounted) return;
                if (watchOnly case Ok(value: final value?)) {
                  ImportNavigation.replaceWithWatchOnly(context, value);
                } else {
                  _handled = false;
                }
              } catch (error) {
                if (error is Error) rethrow;
                log.warning('Failed to parse scanned watch-only');
                _handled = false;
              }
            },
          ),
          if (_scanned.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: 24,
              right: 24,
              child: BullButton.secondary(
                iconData: Icons.copy,
                textStyle: context.bullType.caption,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _scanned));
                  showCopiedSnackBar(context);
                },
                label: _scanned.length > 30
                    ? '${_scanned.substring(0, 10)}…${_scanned.substring(_scanned.length - 10)}'
                    : _scanned,
              ),
            ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.02,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                onPressed: () => context.pop(),
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

void showCopiedSnackBar(BuildContext context) {
  BullSnackBar.show(
    context,
    message: context.loc.importWatchOnlyCopiedToClipboard,
  );
}
