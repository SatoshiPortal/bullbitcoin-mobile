import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/funding/presentation/funding_rail_copy.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_detail.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullInfoCard,
        BullQrCode,
        BullShapesX,
        BullText,
        BullTypographyX,
        Gap;
import 'package:exchange/funding.dart';
import 'package:material_ui/material_ui.dart';

/// The one instructions screen body for every rail (composition §3.2): the
/// rail's copy around the server's values, as rows, a QR code or a link.
/// It is only built with instructions the exchange gave; there is no
/// placeholder value (FUND-1).
class FundingInstructionsView extends StatelessWidget {
  const FundingInstructionsView({
    super.key,
    required this.rail,
    required this.instructions,
    required this.onOpenLink,
  });

  final FundingRail rail;
  final FundingInstructions instructions;
  final void Function(Uri link) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final copy = rail.instructionsCopy(context);
    final qrLabel = copy.fields[InstructionField.transferCode]?.label;
    final subtitle = context.bullType.subtitle.copyWith(
      fontWeight: FontWeight.w400,
    );
    return Column(
      crossAxisAlignment: .start,
      children: [
        BullText(copy.title, style: context.bullType.headline),
        const Gap(16.0),
        for (final paragraph in copy.intro) ...[
          RichText(
            text: TextSpan(
              children: [
                for (final part in paragraph)
                  TextSpan(
                    text: part.text,
                    style: part.bold
                        ? subtitle.copyWith(fontWeight: .bold)
                        : subtitle,
                  ),
              ],
            ),
          ),
          const Gap(16.0),
        ],
        for (final step in copy.steps)
          BullText(step, style: context.bullType.body),
        if (copy.steps.isNotEmpty) const Gap(16.0),
        if (copy.warning case final warning?) ...[
          _Warning(parts: warning),
          const Gap(24.0),
        ],
        if (copy.notice case final notice?) ...[
          _Notice(text: notice),
          const Gap(24.0),
        ],
        ...switch (instructions) {
          // Each rail's copy names every field the rail shows (pinned by
          // funding_rail_copy_test), so every row has its label.
          FundingInstructionRows(:final rows) => [
            for (final row in rows)
              if (copy.fields[row.field] case final field?)
                ..._row(context, field, row.value),
          ],
          FundingInstructionQr(:final payload) => [
            Center(
              child: Column(
                children: [
                  if (qrLabel case final label?) ...[
                    BullText(
                      label,
                      style: context.bullType.body,
                      textAlign: .center,
                    ),
                    const Gap(8.0),
                  ],
                  BullQrCode(data: payload, size: 250, semanticsLabel: qrLabel),
                  const Gap(24.0),
                ],
              ),
            ),
          ],
          FundingInstructionLink(:final link) => [
            BullButton.primary(
              label: context.loc.fundExchangeCopOpenPaymentLink,
              iconData: Icons.open_in_new,
              onPressed: () => onOpenLink(link),
            ),
          ],
        },
      ],
    );
  }

  List<Widget> _row(BuildContext context, FieldCopy copy, String value) => [
    FundExchangeDetail(label: copy.label, helpText: copy.help, value: value),
    if (copy.notice case final notice?) ...[
      const Gap(16.0),
      _Notice(text: notice),
    ],
    const Gap(24.0),
  ];
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => BullInfoCard(
    bgColor: context.appColors.inverseSurface.withValues(alpha: 0.1),
    tagColor: context.appColors.secondary,
    description: text,
  );
}

class _Warning extends StatelessWidget {
  const _Warning({required this.parts});

  final List<CopyPart> parts;

  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: .hardEdge,
    decoration: BoxDecoration(
      color: context.appColors.inverseSurface.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(context.bullShapes.card),
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: .stretch,
        children: [
          Container(width: 4, color: context.appColors.inverseSurface),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: .start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 24,
                    color: context.appColors.inverseSurface,
                  ),
                  const Gap(12),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        children: [
                          for (final part in parts)
                            TextSpan(
                              text: part.text,
                              style: context.bullType.body.copyWith(
                                color: context.appColors.secondary,
                                fontWeight: part.bold
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
