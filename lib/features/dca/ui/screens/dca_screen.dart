import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/dca/domain/dca.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_amount_input_fields.dart';
import 'package:bb_mobile/features/dca/ui/widgets/dca_frequency_radio_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class DcaScreen extends StatefulWidget {
  const DcaScreen({super.key});

  @override
  State<DcaScreen> createState() => _DcaScreenState();
}

class _DcaScreenState extends State<DcaScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController = TextEditingController();
  late FiatCurrency _fiatCurrency;
  DcaBuyFrequency? _frequency;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<DcaBloc>();
    _fiatCurrency = bloc.state.currency;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set recurring buy')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ScrollableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Gap(24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Text(
                  'Bitcoin purchases will be placed automatically per this schedule.',
                  style: context.theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              const Gap(24),
              DcaAmountInputFields(
                amountController: _amountController,
                fiatCurrency: _fiatCurrency,
                onFiatCurrencyChanged: (fiatCurrency) {
                  setState(() {
                    _fiatCurrency = fiatCurrency;
                  });
                },
              ),
              const Gap(24),
              FormField<DcaBuyFrequency>(
                initialValue: _frequency,
                validator:
                    (val) => val == null ? 'Please select a frequency' : null,
                builder: (field) {
                  return DcaFrequencyRadioList(
                    selectedFrequency: field.value,
                    onChanged: (freq) {
                      field.reset();
                      setState(() => _frequency = freq);
                      field.didChange(freq);
                    },
                    errorText: field.errorText,
                  );
                },
              ),
              const Spacer(),
              BBButton.big(
                label: 'Continue',
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    context.read<DcaBloc>().add(
                      DcaEvent.buyInputContinuePressed(
                        amountInput: _amountController.text,
                        currency: _fiatCurrency,
                        frequency: _frequency!,
                      ),
                    );
                  }
                },
                bgColor: context.colour.secondary,
                textColor: context.colour.onSecondary,
              ),
              const Gap(16.0),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }
}
