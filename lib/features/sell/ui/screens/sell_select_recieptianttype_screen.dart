import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellSelecRecieptiantTypeScreen extends StatelessWidget {
  const SellSelecRecieptiantTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Sell Bitcoin',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: SellSelectRecieptiantTypeForm(),
      ),
    );
  }
}

class SellSelectRecieptiantTypeForm extends StatefulWidget {
  const SellSelectRecieptiantTypeForm({super.key});

  @override
  _SellSelectRecieptiantTypeFormState createState() =>
      _SellSelectRecieptiantTypeFormState();
}

class _SellSelectRecieptiantTypeFormState
    extends State<SellSelectRecieptiantTypeForm> {
  String? _selectedPayoutMethod = 'Add to my account balance';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Select country', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                value: 'CAD',
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'CAD',
                    child: BBText('CAD', style: context.font.headlineSmall),
                  ),
                  DropdownMenuItem(
                    value: 'USD',
                    child: BBText('USD', style: context.font.headlineSmall),
                  ),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText('Payout method', style: context.font.bodyMedium),
        const Gap(4.0),
        _buildPayoutMethodOption(context, 'Add to my account balance'),
        _buildPayoutMethodOption(context, 'Bank account'),
        _buildPayoutMethodOption(context, 'Email money transfer'),
        _buildPayoutMethodOption(context, 'Standard biller'),
        const Spacer(),
        BBButton.big(
          label: 'Continue',
          onPressed: () {},
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
        const Gap(40),
      ],
    );
  }

  Widget _buildPayoutMethodOption(BuildContext context, String method) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPayoutMethod = method;
        });
      },
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          border: Border.all(
            color:
                _selectedPayoutMethod == method
                    ? context.colour.primary
                    : context.colour.surface,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Row(
          children: [
            Radio<String>(
              value: method,
              groupValue: _selectedPayoutMethod,
              onChanged: (value) {
                setState(() {
                  _selectedPayoutMethod = value;
                });
              },
              activeColor: context.colour.primary,
            ),
            BBText(method, style: context.font.bodyMedium),
          ],
        ),
      ),
    );
  }
}
