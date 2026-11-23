import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:gif/gif.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;

class NfcScannerWidget extends StatefulWidget {
  final FutureOr<void> Function(NFCTag tag) onScanned;
  final void Function(Object error)? onError;
  final bool scanOnInit;
  final Widget? loadingWidget;
  final String rescanLabel;

  const NfcScannerWidget({
    super.key,
    required this.onScanned,
    required this.rescanLabel,
    this.onError,
    this.scanOnInit = true,
    this.loadingWidget,
  });

  @override
  State<NfcScannerWidget> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcScannerWidget> {
  NFCTag? _tag;

  Future<void> _scan() async {
    if (mounted) setState(() => _tag = null);

    final NFCTag tag;
    try {
      // Coldcard uses NFC-V / ISO-15693.
      tag = await FlutterNfcKit.poll(readIso15693: true, readIso18092: false);
    } catch (e) {
      widget.onError?.call(e);
      if (!mounted) return;
      setState(() => _tag = null);
      return;
    }

    if (!mounted) return;
    await widget.onScanned(tag);
    if (!mounted) return;
    setState(() => _tag = tag);
  }

  @override
  void initState() {
    super.initState();
    if (widget.scanOnInit) unawaited(_scan());
  }

  @override
  void dispose() {
    unawaited(_finishNfcSession());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loadingWidget =
        widget.loadingWidget ??
        Center(
          child: SizedBox(
            width: 250,
            height: 250,
            child: Gif(
              image: const AssetImage(
                'assets/nfc_poll.gif',
                package: 'scanning',
              ),
              autostart: Autostart.loop,
            ),
          ),
        );

    return Column(
      mainAxisAlignment: .center,
      children: [
        if (_tag == null) loadingWidget,

        if (_tag != null)
          BullButton.secondary(
            label: widget.rescanLabel,
            onPressed: _scan,
            iconData: Icons.nfc,
          ),
      ],
    );
  }

  Future<void> _finishNfcSession() async {
    try {
      await FlutterNfcKit.finish();
    } catch (_) {}
  }
}
