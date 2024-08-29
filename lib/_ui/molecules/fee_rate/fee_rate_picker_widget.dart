import 'package:bb_mobile/_pkg/fee_rate/models/fee_rate.dart';
import 'package:bb_mobile/_ui/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const minDefaultFeeRate = 10;
const maxDefaultFeeRate = 1000;

class FeeRatePicker extends StatefulWidget {
  const FeeRatePicker({
    super.key,
    required this.selectedFeeRate,
    required this.feeRate,
    required this.currentFeeRate,
    required this.onDefaultFeeRateChange,
  });

  final FeeRateType selectedFeeRate;
  final int feeRate;
  final FeeRate currentFeeRate;

  final Function({
    required int updatedDefaultFeeRate,
    required FeeRateType selectedFeeRate,
  }) onDefaultFeeRateChange;

  @override
  State<FeeRatePicker> createState() => _FeeRatePickerState();
}

class _FeeRatePickerState extends State<FeeRatePicker> {
  FeeRateType selectedFeeRate = FeeRateType.fastest;

  TextEditingController textEditingController =
      TextEditingController(text: '0');
  final _customFeeRateKey = GlobalKey<FormFieldState>();

  @override
  void initState() {
    super.initState();
    selectedFeeRate = widget.selectedFeeRate;

    if (selectedFeeRate == FeeRateType.custom) {
      textEditingController.text = widget.feeRate.toString();
    }

    textEditingController.addListener(() {
      if (textEditingController.text != '0') {
        selectedFeeRate = FeeRateType.custom;
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    textEditingController.dispose();
  }

  void _onFeeRateSelected(FeeRateType feeRate) {
    setState(() {
      selectedFeeRate = feeRate;
      textEditingController.text = '0';
    });
  }

  void _onDoneTap() {
    int rate = widget.currentFeeRate.getFeeValue(selectedFeeRate);

    if (selectedFeeRate == FeeRateType.custom) {
      rate = int.parse(textEditingController.text);
    }

    widget.onDefaultFeeRateChange(
      updatedDefaultFeeRate: rate,
      selectedFeeRate: selectedFeeRate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            RadioListTile(
              value: FeeRateType.fastest,
              groupValue: selectedFeeRate,
              title: Text('Fastest ${widget.currentFeeRate.fastest}'),
              onChanged: (val) {
                _onFeeRateSelected(FeeRateType.fastest);
              },
            ),
            RadioListTile(
              value: FeeRateType.fast,
              groupValue: selectedFeeRate,
              title: Text('Fast ${widget.currentFeeRate.fast}'),
              onChanged: (val) {
                _onFeeRateSelected(FeeRateType.fast);
              },
            ),
            RadioListTile(
              value: FeeRateType.medium,
              groupValue: selectedFeeRate,
              title: Text('Medium ${widget.currentFeeRate.medium}'),
              onChanged: (val) {
                _onFeeRateSelected(FeeRateType.medium);
              },
            ),
            RadioListTile(
              value: FeeRateType.slow,
              groupValue: selectedFeeRate,
              title: Text('Slow ${widget.currentFeeRate.slow}'),
              onChanged: (val) {
                _onFeeRateSelected(FeeRateType.slow);
              },
            ),
            TextFormField(
              key: _customFeeRateKey,
              controller: textEditingController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                focusedBorder: OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(),
                focusedErrorBorder: errorBorder,
                errorBorder: errorBorder,
                errorStyle: TextStyle(
                  color: Colors.red,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter number between $minDefaultFeeRate to $maxDefaultFeeRate';
                }

                final int? intValue = int.tryParse(value);

                if (intValue == null) {
                  return 'Please enter valid number between $minDefaultFeeRate to $maxDefaultFeeRate';
                }

                if (intValue < minDefaultFeeRate) {
                  return 'Fee rate should not be less than $minDefaultFeeRate';
                }

                if (intValue > maxDefaultFeeRate) {
                  return 'Fee rate should not be greater than $maxDefaultFeeRate';
                }

                return null;
              },
            ),
            ElevatedButton(
              child: const Text('Done'),
              onPressed: () {
                // print('onPressed');
                // print(selectedFeeRate);
                if (selectedFeeRate != FeeRateType.custom ||
                    _customFeeRateKey.currentState!.validate()) {
                  _onDoneTap();
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
