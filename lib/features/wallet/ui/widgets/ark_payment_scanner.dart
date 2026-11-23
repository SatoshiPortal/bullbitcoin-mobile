import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:scanning/scanning.dart';
import 'package:bull_ui/bull_ui.dart';

/// Reuses the camera decoder without parsing or choosing a payment protocol.
Future<String?> scanArkPayment(
  BuildContext context,
  String title, {
  Widget Function(ValueChanged<String>)? scannerBuilder,
}) => Navigator.of(context).push<String>(
  MaterialPageRoute(
    builder: (context) => _ArkPaymentScanner(
      title: title,
      scannerBuilder:
          scannerBuilder ??
          (onScanned) => QrScannerWidget(
            labels: context.loc.qrScanning,
            onScanned: onScanned,
          ),
    ),
  ),
);

class _ArkPaymentScanner extends StatefulWidget {
  final String title;
  final Widget Function(ValueChanged<String>) scannerBuilder;

  const _ArkPaymentScanner({required this.title, required this.scannerBuilder});

  @override
  State<_ArkPaymentScanner> createState() => _ArkPaymentScannerState();
}

class _ArkPaymentScannerState extends State<_ArkPaymentScanner> {
  bool _completed = false;

  void _finish(String? value) {
    if (!mounted || _completed) return;
    _completed = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => PopScope<String>(
    onPopInvokedWithResult: (didPop, _) {
      if (didPop) _completed = true;
    },
    child: BullScaffold(
      backgroundColor: context.bull.background,
      body: SafeArea(
        child: Column(
          children: [
            BullTopBar(title: widget.title, onBack: () => _finish(null)),
            Expanded(child: widget.scannerBuilder(_finish)),
          ],
        ),
      ),
    ),
  );
}
