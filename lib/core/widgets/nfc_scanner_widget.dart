import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:gif/gif.dart';

class NfcScannerWidget extends StatefulWidget {
  final void Function(NFCTag tag) onScanned;
  final bool scanOnInit;
  final Widget? loadingWidget;

  const NfcScannerWidget({
    super.key,
    required this.onScanned,
    this.scanOnInit = true,
    this.loadingWidget,
  });

  @override
  State<NfcScannerWidget> createState() => _NfcPageState();
}

class _NfcPageState extends State<NfcScannerWidget> {
  NFCTag? _tag;

  Future<void> _scan() async {
    setState(() => _tag = null);
    final tag = await FlutterNfcKit.poll();
    widget.onScanned(tag);
    setState(() => _tag = tag);
  }

  @override
  void initState() {
    super.initState();
    if (widget.scanOnInit) _scan();
  }

  @override
  Widget build(BuildContext context) {
    final loadingWidget =
        widget.loadingWidget ??
        Center(
          child: Gif(
            image: AssetImage(Assets.animations.nfcPoll.path),
            autostart: Autostart.loop,
          ),
        );

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_tag == null) loadingWidget,

        if (_tag != null)
          BBButton.big(
            label: 'Scan NFC',
            onPressed: _scan,
            bgColor: context.colour.onPrimary,
            textColor: context.colour.secondary,
            iconData: Icons.nfc,
          ),
      ],
    );
  }
}
