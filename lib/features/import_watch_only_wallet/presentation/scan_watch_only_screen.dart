import 'dart:convert';
import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/qr_scanner_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:go_router/go_router.dart';
import 'package:satoshifier/satoshifier.dart';

class ScanWatchOnlyScreen extends StatefulWidget {
  final SignerDeviceEntity? signerDevice;

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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          QrScannerWidget(
            scanDelay:
                widget.signerDevice?.supportedQrType == QrType.urqr
                    ? Duration.zero
                    : const Duration(milliseconds: 100),
            resolution: ResolutionPreset.high,
            onScanned: (data) async {
              if (_handled) return;
              _handled = true;
              setState(() => _scanned = data);
              try {
                String signerData = data;
                if (widget.signerDevice == SignerDeviceEntity.krux) {
                  signerData = Descriptor.parse(data).external;
                } else if (widget.signerDevice == SignerDeviceEntity.passport) {
                  final selectedDescriptor = await _choosePassportDerivation(
                    context,
                    data,
                  );
                  if (selectedDescriptor == null) return;
                  signerData = selectedDescriptor;
                }
                final watchOnly = await Satoshifier.parse(signerData);

                if (watchOnly is WatchOnlyDescriptor) {
                  final watchOnlyDescriptor = WatchOnlyWalletEntity.descriptor(
                    watchOnlyDescriptor: watchOnly,
                    signerDevice: widget.signerDevice,
                  );

                  if (!context.mounted) return;
                  context.replaceNamed(
                    ImportWatchOnlyWalletRoutes.import.name,
                    extra: watchOnlyDescriptor,
                  );
                }

                if (watchOnly is WatchOnlyXpub) {
                  final watchOnlyXpub = WatchOnlyWalletEntity.xpub(
                    watchOnlyXpub: watchOnly,
                  );

                  if (!context.mounted) return;
                  context.replaceNamed(
                    ImportWatchOnlyWalletRoutes.import.name,
                    extra: watchOnlyXpub,
                  );
                }
              } catch (e) {
                log.warning(e.toString());
              }
            },
          ),
          if (_scanned.isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.25,
              left: 24,
              right: 24,
              child: BBButton.big(
                iconData: Icons.copy,
                textStyle: context.font.labelMedium,
                textColor: context.appColors.onPrimary,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _scanned));
                  showCopiedSnackBar(context);
                },
                label:
                    _scanned.length > 30
                        ? '${_scanned.substring(0, 10)}…${_scanned.substring(_scanned.length - 10)}'
                        : _scanned,
                bgColor: Colors.transparent,
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        context.loc.importWatchOnlyCopiedToClipboard,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, color: Colors.white),
      ),
      duration: const Duration(seconds: 2),
      backgroundColor: Theme.of(context).colorScheme.onSurface.withAlpha(204),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}

// Passport exports multiple derivations so we need to let the user choose which one to use
Future<String?> _choosePassportDerivation(
  BuildContext context,
  String data,
) async {
  try {
    final parsed = json.decode(data);
    if (parsed is! Map<String, dynamic>) return null;

    final options = <Map<String, String>>[];

    void addIfPresent(String key, String label) {
      if (!parsed.containsKey(key)) return;
      final descriptor = parsed[key];
      if (descriptor is String) {
        options.add({'key': key, 'label': label, 'descriptor': descriptor});
      }
    }

    addIfPresent('bip84', 'Segwit (BIP84)');
    addIfPresent('bip49', 'Nested Segwit (BIP49)');
    addIfPresent('bip44', 'Legacy (BIP44)');

    if (options.isEmpty) return null;
    if (options.length == 1) return options.first['descriptor'];

    if (!context.mounted) return null;
    final choice = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  ctx.loc.importWatchOnlySelectDerivation,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              for (final opt in options)
                ListTile(
                  title: Text(opt['label'] ?? ''),
                  onTap: () => Navigator.of(ctx).pop(opt),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    return choice?['descriptor'];
  } catch (_) {
    return null;
  }
}
