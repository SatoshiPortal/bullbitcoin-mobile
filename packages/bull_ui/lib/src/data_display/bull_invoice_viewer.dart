import 'package:material_ui/material_ui.dart';

import 'bull_value_viewer.dart';

/// Displays a Lightning invoice with an action to copy its exact value.
class BullInvoiceViewer extends StatelessWidget {
  final String data;
  final String title;
  final String copyLabel;
  final String copiedMessage;
  final TextStyle? style;
  final Color? color;
  final String? clipboardText;

  const BullInvoiceViewer(
    this.data, {
    super.key,
    required this.title,
    required this.copyLabel,
    required this.copiedMessage,
    this.style,
    this.color,
    this.clipboardText,
  });

  @override
  Widget build(BuildContext context) => BullValueViewer(
    data,
    title: title,
    copyLabel: copyLabel,
    copiedMessage: copiedMessage,
    style: style,
    color: color,
    clipboardText: clipboardText,
  );

  /// Opens the invoice details when a surrounding control handles the tap.
  static Future<void> showDetail(
    BuildContext context, {
    required String data,
    required String title,
    required String copyLabel,
    required String copiedMessage,
    String? clipboardText,
  }) => BullValueViewer.showDetail(
    context,
    data: data,
    title: title,
    copyLabel: copyLabel,
    copiedMessage: copiedMessage,
    clipboardText: clipboardText,
  );
}
