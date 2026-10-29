import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:transaction_sync/transaction_sync.dart' show BitcoinSyncSource;

class BitcoinSyncSourceCards extends StatelessWidget {
  final BitcoinSyncSource value;
  final ValueChanged<BitcoinSyncSource> onChanged;

  const BitcoinSyncSourceCards({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      BullSelectableList(
        selectedValue: value.name,
        onChanged: (name) => onChanged(BitcoinSyncSource.values.byName(name)),
        items: [
          BullSelectableListItem(
            title: context.loc.syncFastTitle,
            subtitle1: context.loc.syncFastDescription,
            subtitle2: context.loc.syncElectrumProtocol,
            value: BitcoinSyncSource.electrum.name,
          ),
          BullSelectableListItem(
            title: context.loc.syncPrivateTitle,
            subtitle1: context.loc.syncPrivateDescription,
            subtitle2: context.loc.syncCbfProtocol,
            value: BitcoinSyncSource.compactBlockFilters.name,
          ),
        ],
      ),
      BullText(context.loc.syncChangeLater, style: context.bullText.bodyMedium),
    ],
  );
}
