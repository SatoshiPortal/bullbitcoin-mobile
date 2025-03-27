import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BuyAmountScreen extends StatelessWidget {
  const BuyAmountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Buy Bitcoin',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.all(16.0),
        child: BuyAmountForm(),
      ),
    );
  }
}

class BuyAmountForm extends StatelessWidget {
  const BuyAmountForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(24),
        BBText(
          'You pay',
          style: context.font.bodyMedium,
        ),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                initialValue: '0 CAD',
                style: context.font.headlineMedium,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
              ),
            ),
          ),
        ),
        const Gap(2.0),
        BBText(
          'Balance: 1110.00 CAD',
          style: context.font.labelSmall,
          color: context.colour.outline,
        ),
        const Gap(16.0),
        BBText(
          'Payment method',
          style: context.font.bodyMedium,
        ),
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
                    child: BBText(
                      'CAD',
                      style: context.font.headlineSmall,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'USD',
                    child: BBText(
                      'USD',
                      style: context.font.headlineSmall,
                    ),
                  ),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText(
          'Select wallet',
          style: context.font.bodyMedium,
        ),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 4,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(4.0),
            child: Center(
              child: DropdownButtonFormField<String>(
                alignment: Alignment.center,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.0),
                ),
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: context.colour.secondary,
                ),
                value: 'External Bitcoin wallet',
                items: [
                  DropdownMenuItem(
                    value: 'External Bitcoin wallet',
                    child: BBText(
                      'External Bitcoin wallet',
                      style: context.font.headlineSmall,
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'Secure Bitcoin Wallet',
                    child: BBText(
                      'Secure Bitcoin Wallet',
                      style: context.font.headlineSmall,
                    ),
                  ),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText(
          'Enter bitcoin address',
          style: context.font.bodyMedium,
        ),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                initialValue: 'BC1QYL7J673H...6Y6ALV70M0',
                textAlignVertical: TextAlignVertical.center,
                style: context.font.headlineSmall,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.copy, color: context.colour.secondary),
                    onPressed: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
        const Gap(16.0),
        const Spacer(),
        BBButton.big(
          label: 'Continue',
          onPressed: () {},
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
        const Gap(24),
      ],
    );
  }
}
