import 'package:bull_ui/src/buttons/bull_button.dart';
import 'package:bull_ui/src/data_display/bull_info_card.dart';
import 'package:bull_ui/src/inputs/bull_copy_field.dart';
import 'package:bull_ui/src/layout/gap.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:flutter/material.dart';

/// A notice that hands the user a reference to keep and one way out: an info
/// card with [message], the copyable [reference] and a single action button.
///
/// Built for "payment sent, but the exchange reports the deadline passed —
/// keep this transaction ID for support and leave"; generic enough for any
/// outcome that ends with a reference and an exit. The kit has no
/// localisation, so every string comes translated from the caller. Colours
/// default to the theme's tertiary tint for the card and secondary for the
/// action, and can each be overridden.
class BullReferenceNotice extends StatelessWidget {
  const BullReferenceNotice({
    super.key,
    required this.message,
    required this.reference,
    required this.copiedMessage,
    required this.actionLabel,
    required this.onAction,
    this.tagColor,
    this.bgColor,
    this.actionBgColor,
    this.actionTextColor,
  });

  /// What happened and what to do with the reference.
  final String message;

  /// The value to keep, shown in a [BullCopyField].
  final String reference;

  /// Toast shown once [reference] is on the clipboard.
  final String copiedMessage;

  /// Label of the single action, typically a way out of the flow.
  final String actionLabel;
  final VoidCallback onAction;

  /// Accent of the info card; the theme's tertiary when null.
  final Color? tagColor;

  /// Fill of the info card; the theme's tertiary container when null.
  final Color? bgColor;

  /// Fill of the action; the theme's secondary when null.
  final Color? actionBgColor;

  /// Text of the action; the theme's on-secondary when null.
  final Color? actionTextColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BullInfoCard(
          description: message,
          tagColor: tagColor ?? colors.tertiary,
          bgColor: bgColor ?? colors.tertiaryContainer,
        ),
        const Gap(12),
        BullCopyField(
          text: reference,
          copiedMessage: copiedMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Gap(16),
        BullButton.big(
          label: actionLabel,
          onPressed: onAction,
          bgColor: actionBgColor ?? colors.secondary,
          textColor: actionTextColor ?? colors.onSecondary,
        ),
      ],
    );
  }
}
