import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:gif/gif.dart';

class NfcScannerWidget extends StatefulWidget {
  final FutureOr<void> Function(NFCTag tag) onScanned;
  final void Function(Object error)? onError;
  final bool scanOnInit;
  final Widget? loadingWidget;

  const NfcScannerWidget({
    super.key,
    required this.onScanned,
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
              image: AssetImage(Assets.animations.nfcPoll.path),
              autostart: Autostart.loop,
            ),
          ),
        );

    return Column(
      mainAxisAlignment: .center,
      children: [
        if (_tag == null) loadingWidget,

        if (_tag != null)
          BBButton.big(
            label: context.loc.scanNfcButton,
            onPressed: _scan,
            bgColor: context.appColors.onPrimary,
            textColor: context.appColors.secondary,
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
