import 'package:bull_ui/bull_ui.dart';

/// Full address for read-only review; callbacks only view or copy it.
class SendGroupedAddress extends StatelessWidget {
  const SendGroupedAddress({
    super.key,
    required this.address,
    required this.onOpen,
    required this.onCopy,
  });
  final String address;
  final VoidCallback onOpen;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: address,
    excludeSemantics: true,
    onTap: onOpen,
    onLongPress: onCopy,
    child: GestureDetector(
      onTap: onOpen,
      onLongPress: onCopy,
      child: Wrap(
        spacing: BullSpacing.xs,
        runSpacing: BullSpacing.xs,
        children: [
          for (var i = 0; i < address.length; i += 4)
            Text(
              address.substring(
                i,
                i + 4 > address.length ? address.length : i + 4,
              ),
              style: context.bullType.body.copyWith(
                color: (i ~/ 4).isOdd
                    ? context.bull.textMuted
                    : context.bull.text,
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
        ],
      ),
    ),
  );
}
