import 'package:bb_mobile/_pkg/fee_rate/models/fee_rate.dart';
import 'package:bb_mobile/_ui/molecules/fee_rate/fee_rate_picker_widget.dart';
import 'package:flutter/material.dart';

class FeeRateSelector extends StatelessWidget {
  const FeeRateSelector({
    super.key,
    required this.label,
    required this.selectedFeeRate,
    required this.feeRate,
    required this.currentFeeRate,
    required this.onDefaultFeeRateChange,
  });

  final String label;

  final FeeRateType selectedFeeRate;
  final int feeRate;
  final FeeRate currentFeeRate;

  final Function({
    required int updatedDefaultFeeRate,
    required FeeRateType selectedFeeRate,
  }) onDefaultFeeRateChange;

  void _onTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Wrap(
              children: [
                FeeRatePicker(
                  currentFeeRate: currentFeeRate,
                  feeRate: feeRate,
                  onDefaultFeeRateChange: onDefaultFeeRateChange,
                  selectedFeeRate: selectedFeeRate,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: SizedBox(
        width: 100,
        child: Row(
          children: [
            Text('$feeRate sats/vB'),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
      onTap: () => _onTap(context),
    );
  }
}
