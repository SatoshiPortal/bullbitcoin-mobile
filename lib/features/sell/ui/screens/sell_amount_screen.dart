import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SellAmountScreen extends StatelessWidget {
  const SellAmountScreen({super.key});

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
        child: SellAmountForm(),
      ),
    );
  }
}

class SellAmountForm extends StatelessWidget {
  const SellAmountForm({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BBText('You pay', style: context.font.bodyMedium),
        const Gap(4.0),
        SizedBox(
          height: 56,
          child: Material(
            elevation: 2,
            color: context.colour.onPrimary,
            borderRadius: BorderRadius.circular(2.0),
            child: Center(
              child: TextFormField(
                initialValue: '1000 CAD',
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
          'Balance: ~0.00 BTC',
          style: context.font.labelSmall,
          color: context.colour.outline,
        ),
        const Gap(16.0),
        BBText('Select currency', style: context.font.bodyMedium),
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
                    value: 'EUR',
                    child: BBText('EUR', style: context.font.headlineSmall),
                  ),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        ),
        const Gap(16.0),
        BBText('Network', style: context.font.bodyMedium),
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
                value: 'Bitcoin',
                items: [
                  DropdownMenuItem(
                    value: 'Bitcoin',
                    child: BBText('Bitcoin', style: context.font.headlineSmall),
                  ),
                  DropdownMenuItem(
                    value: 'Liquid',
                    child: BBText('Liquid', style: context.font.headlineSmall),
                  ),
                ],
                onChanged: (value) {},
              ),
            ),
          ),
        ),
        const Spacer(),
        BBButton.big(
          label: 'Continue',
          onPressed: () {},
          disabled: true,
          bgColor: context.colour.secondary,
          textColor: context.colour.onSecondary,
        ),
        const Gap(40),
      ],
    );
  }
}
