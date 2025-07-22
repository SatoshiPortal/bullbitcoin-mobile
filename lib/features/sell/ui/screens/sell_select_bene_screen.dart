import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/segment/segmented_full.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellSelectBeneficiaryScreen extends StatefulWidget {
  const SellSelectBeneficiaryScreen({super.key});

  @override
  State<SellSelectBeneficiaryScreen> createState() =>
      _SellSelectBeneficiaryScreenState();
}

class _SellSelectBeneficiaryScreenState
    extends State<SellSelectBeneficiaryScreen> {
  String selectedSegment = 'New beneficiary';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Select beneficiary',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BBText(
              'Where and how should we send the money?',
              style: context.font.bodyMedium,
            ),
            const Gap(16.0),
            BBSegmentFull(
              items: const {'New beneficiary', 'My beneficiaries'},
              onSelected: (value) {
                setState(() {
                  selectedSegment = value;
                });
              },
            ),
            const Gap(16.0),
            if (selectedSegment == 'New beneficiary')
              _buildNewBeneficiaryForm(context),
            if (selectedSegment == 'My beneficiaries')
              _buildBeneficiariesList(context),
            // const Spacer(),
            const Gap(24),
            BBButton.big(
              label:
                  selectedSegment == 'New beneficiary' ? 'Save and Pay' : 'Pay',
              onPressed: () {},
              bgColor: context.colour.secondary,
              textColor: context.colour.onSecondary,
            ),
            const Gap(40),
          ],
        ),
      ),
    );
  }

  Widget _buildNewBeneficiaryForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('Payout method', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                initialValue: 'Wire Transfer',
                style: context.font.headlineMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText('Institution Number', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                style: context.font.headlineMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText('Transit Number', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                style: context.font.headlineMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText('Account Number', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                style: context.font.headlineMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText('Label (optional)', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                style: context.font.headlineMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText(
          'Who is the owner of this account?',
          style: context.font.bodyMedium,
        ),
        const Gap(4.0),
        Column(
          children: [
            RadioListTile(
              value: 'my_account',
              groupValue: 'my_account',
              onChanged: (value) {},
              title: BBText(
                'This is my bank account',
                style: context.font.bodyMedium,
              ),
              activeColor: context.colour.primary,
              selectedTileColor: context.colour.secondaryFixedDim,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
                side: BorderSide(color: context.colour.primary),
              ),
            ),
            const Gap(8),
            RadioListTile(
              value: 'someone_else_account',
              groupValue: 'my_account',
              onChanged: (value) {},
              title: BBText(
                "This is someone else's bank account",
                style: context.font.bodyMedium,
              ),
              activeColor: context.colour.primary,
              selectedTileColor: context.colour.secondaryFixedDim,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4.0),
                side: BorderSide(color: context.colour.outline),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBeneficiariesList(BuildContext context) {
    return Column(
      children: [
        _buildBeneficiaryItem(context, 'Alex', true),
        const Gap(8.0),
        _buildBeneficiaryItem(context, 'Alex', false),
      ],
    );
  }

  Widget _buildBeneficiaryItem(
    BuildContext context,
    String name,
    bool selected,
  ) {
    return Material(
      elevation: selected ? 4 : 2,
      color: context.colour.secondaryFixed,
      borderRadius: BorderRadius.circular(4.0),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(
            color: selected ? context.colour.primary : context.colour.outline,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BBText(name, style: context.font.headlineLarge),
                BBText(
                  'Wire Transfer\nAlex poullot\nInstitution Number: 123\nTransit Number: 12345\nAccount Number: 12345678',
                  style: context.font.labelMedium,
                  color: context.colour.outline,
                  maxLines: 12,
                ),
              ],
            ),
            const Spacer(),
            Radio(
              value: selected,
              groupValue: true,
              onChanged: (value) {},
              activeColor: context.colour.primary,
              fillColor: WidgetStateProperty.resolveWith<Color>((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.selected)) {
                  return context.colour.primary;
                }
                return context.colour.outline;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
