import 'package:primitives/primitives.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as widgetbook;

@widgetbook.UseCase(name: 'Bitcoin denominations', type: BullAmount)
Widget bitcoinAmounts(BuildContext context) => const _AmountExample();

class _AmountExample extends StatefulWidget {
  const _AmountExample();

  @override
  State<_AmountExample> createState() => _AmountExampleState();
}

class _AmountExampleState extends State<_AmountExample> {
  BitcoinUnit _unit = BitcoinUnit.sats;
  final _controller = TextEditingController(text: '12345');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BullAmountScope(
    snapshot: BullAmountSnapshot(
      unit: _unit,
      hideAmounts: false,
      isReady: true,
    ),
    writeUnit: (unit) async {
      setState(() => _unit = unit);
      return true;
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BullAmount(magnitude: Sats.fromInt(12345)),
        BullAmount(magnitude: Sats.fromInt(12), isNegative: true),
        BullBitcoinAmountInput(
          canonicalUnit: BitcoinUnit.sats,
          amountController: _controller,
          amountEquivalent: '',
        ),
      ],
    ),
  );
}
