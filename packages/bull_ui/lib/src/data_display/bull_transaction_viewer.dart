import 'package:material_ui/material_ui.dart';

import '../layout/gap.dart';
import 'bull_value_viewer.dart';

/// Displays a transaction ID with copy and caller-supplied explorer actions.
class BullTransactionViewer extends StatelessWidget {
  const BullTransactionViewer(
    this.data, {
    super.key,
    required this.title,
    required this.copyLabel,
    required this.copiedMessage,
    required this.explorerActions,
    required this.openUrl,
    this.style,
    this.color,
    this.clipboardText,
  });

  final String data;
  final String title;
  final String copyLabel;
  final String copiedMessage;
  final TextStyle? style;
  final Color? color;

  /// Text copied in place of the displayed transaction ID.
  final String? clipboardText;

  /// Each action resolves its URL only after the user selects it.
  final List<
    ({String copyLabel, String openLabel, Future<String> Function() resolveUrl})
  >
  explorerActions;

  final Future<void> Function(Uri) openUrl;

  @override
  Widget build(BuildContext context) {
    return BullValueViewer(
      data,
      title: title,
      copyLabel: copyLabel,
      copiedMessage: copiedMessage,
      style: style,
      color: color,
      clipboardText: clipboardText,
      additionalActions: (context) => [
        for (final action in explorerActions) ...[
          const Gap(16),
          BullValueViewer.actionButton(
            icon: Icons.link,
            label: action.copyLabel,
            onTap: () async {
              final url = await action.resolveUrl();
              BullValueViewer.copyFromDialog(context, url, copiedMessage);
            },
          ),
          const Gap(16),
          BullValueViewer.actionButton(
            icon: Icons.open_in_new,
            label: action.openLabel,
            onTap: () async {
              final url = await action.resolveUrl();
              if (context.mounted) Navigator.of(context).pop();
              await openUrl(Uri.parse(url));
            },
          ),
        ],
      ],
    );
  }
}
