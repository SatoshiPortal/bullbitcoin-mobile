import 'dart:async';

import 'package:bb_mobile/core/bbqr/bbqr.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/urqr/urqr.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/settings/domain/wallet_registration.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

class WalletRegistrationQr extends StatefulWidget {
  final String data;
  final WalletRegistrationQrEncoding encoding;

  const WalletRegistrationQr({
    super.key,
    required this.data,
    required this.encoding,
  });

  @override
  State<WalletRegistrationQr> createState() => _WalletRegistrationQrState();
}

class _WalletRegistrationQrState extends State<WalletRegistrationQr> {
  List<String>? _parts;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  @override
  void didUpdateWidget(WalletRegistrationQr oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data ||
        widget.encoding != oldWidget.encoding) {
      _generate();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _generate() async {
    _timer?.cancel();
    _parts = null;
    _index = 0;
    if (mounted) setState(() {});
    late final List<String> parts;
    try {
      parts = switch (widget.encoding) {
        WalletRegistrationQrEncoding.none => <String>[],
        WalletRegistrationQrEncoding.urBytes => UrQrGenerator.generateBytesUr(
          widget.data,
        ),
        WalletRegistrationQrEncoding.bbqrText => await Bbqr.splitText(
          widget.data,
        ),
      };
    } on Exception {
      if (mounted) setState(() => _parts = const []);
      return;
    }
    if (!mounted) return;
    setState(() => _parts = parts);
    if (parts.length > 1) {
      final interval = widget.encoding == WalletRegistrationQrEncoding.bbqrText
          ? const Duration(seconds: 2)
          : const Duration(seconds: 1);
      _timer = Timer.periodic(interval, (_) {
        if (!mounted) return;
        setState(() => _index = (_index + 1) % parts.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts;
    if (parts == null) {
      return const SizedBox(
        height: 280,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (parts.isEmpty) {
      return SizedBox(
        height: 160,
        child: Center(
          child: Text(
            context.loc.walletRegistrationQrError,
            textAlign: TextAlign.center,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.error,
            ),
          ),
        ),
      );
    }
    return Column(
      children: [
        QrDisplayWidget(data: parts[_index], size: 280),
        if (parts.length > 1) ...[
          const Gap(12),
          Text(
            context.loc.psbtFlowPartProgress(
              (_index + 1).toString(),
              parts.length.toString(),
            ),
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}
