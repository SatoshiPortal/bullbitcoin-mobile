import 'package:bull_ui/bull_ui.dart' show BullSizes, Gap;
import 'package:material_ui/material_ui.dart';

import 'wallet_card.dart';

typedef WalletCardRow = ({
  Color tagColor,
  String title,
  String description,
  int? balanceSat,
  bool isSyncing,
  VoidCallback? onTap,
});

class WalletCardList extends StatelessWidget {
  final EdgeInsetsGeometry? padding;
  final List<WalletCardRow> rows;
  final WalletCardRow? silent;
  final String unavailableLabel;

  const WalletCardList({
    super.key,
    this.padding,
    required this.rows,
    required this.silent,
    required this.unavailableLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cards = [...rows, ?silent];
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            13,
            BullSizes.homeCardGap,
            13,
            BullSizes.homeCardGap,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, row) in cards.indexed) ...[
            if (index > 0) const Gap(BullSizes.homeCardGap),
            if (row.balanceSat case final balance?)
              WalletCard(
                tagColor: row.tagColor,
                title: row.title,
                description: row.description,
                balanceSat: balance,
                isSyncing: row.isSyncing,
                onTap: row.onTap,
              )
            else
              ListTile(
                title: Text(row.title),
                subtitle: Text(unavailableLabel),
                onTap: row.onTap,
              ),
          ],
        ],
      ),
    );
  }
}
