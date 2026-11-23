import 'package:labels/labels.dart';
import 'package:label_editor/label_editor.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullAmount, BullThemeX, Gap, BullTypographyX;

import '../presentation/address_view_l10n.dart';
import 'address_viewer.dart';

class AddressCard extends StatelessWidget {
  const AddressCard({
    super.key,
    required this.isUsed,
    required this.address,
    required this.index,
    required this.balanceSat,
    required this.labels,
  });

  final bool isUsed;
  final String address;
  final int index;
  final int balanceSat;
  final List<Label> labels;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: .start,
          mainAxisSize: .min,
          children: [
            Text(
              isUsed
                  ? context.loc.addressCardUsedLabel
                  : context.loc.addressCardUnusedLabel,
              style: context.bullType.body.copyWith(
                color: context.bull.onSurface,
              ),
            ),
            const Gap(8),
            AddressViewer(
              address,
              style: context.bullType.subtitle.copyWith(
                fontWeight: FontWeight.w500,
              ),
              color: context.bull.primary,
            ),
            const Gap(8),
            Text(
              '${context.loc.addressCardIndexLabel}$index',
              style: context.bullType.body.copyWith(
                color: context.bull.textMuted,
              ),
            ),
            const Gap(8),
            Row(
              children: [
                Text(
                  context.loc.addressCardBalanceLabel,
                  style: context.bullType.body.copyWith(
                    color: context.bull.textMuted,
                  ),
                ),
                BullAmount.signedSats(
                  balanceSat,
                  style: context.bullType.body.copyWith(
                    color: context.bull.textMuted,
                  ),
                  interactive: false,
                ),
              ],
            ),
            if (labels.isNotEmpty) ...[
              const Gap(8),
              LabelsWidget(labels: labels),
            ],
          ],
        ),
      ),
    );
  }
}
