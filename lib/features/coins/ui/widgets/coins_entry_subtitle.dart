import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BuildContext,
        BullAmount,
        BullThemeX,
        BullTypographyX,
        PlaceholderAlignment,
        StatelessWidget,
        Text,
        TextBaseline,
        TextSpan,
        Widget,
        WidgetSpan;
import 'package:primitives/primitives.dart' show Sats;

/// `{n} UTXOs · {frozen} frozen`, the frozen clause omitted when nothing is
/// frozen. The frozen amount follows the default BTC/sats unit. It is
/// display-only because the entry is already tappable.
class CoinsEntrySubtitle extends StatelessWidget {
  const CoinsEntrySubtitle({
    super.key,
    required this.utxoCount,
    required this.frozenSat,
  });

  final int utxoCount;
  final BigInt frozenSat;

  // Marks where the localized sentence puts the amount.
  static const _marker = '\u{E000}';

  @override
  Widget build(BuildContext context) {
    final style = context.bullType.caption.copyWith(
      color: context.bull.textMuted,
    );
    final count = context.loc.walletCoinsEntryUtxoCount(utxoCount);
    if (frozenSat <= BigInt.zero) return Text(count, style: style);

    final parts = context.loc.walletCoinsEntryFrozen(_marker).split(_marker);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(text: '$count · ${parts.first}'),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: BullAmount(
              magnitude: Sats(frozenSat),
              interactive: false,
              style: style,
              color: style.color,
            ),
          ),
          if (parts.length > 1) TextSpan(text: parts.last),
        ],
      ),
    );
  }
}
