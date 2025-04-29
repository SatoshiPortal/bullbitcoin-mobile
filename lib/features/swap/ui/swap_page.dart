// ignore_for_file: dead_code

import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/inputs/text_input.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

enum _SwapCardType { pay, receive }

enum _SwapDropdownType { from, to }

class SwapPage extends StatelessWidget {
  const SwapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Swap',
          color: context.colour.secondaryFixedDim,
          onBack: () => context.pop(),
        ),
      ),
      body: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwapFromToDropdown(type: _SwapDropdownType.from),
            Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SwapCard(type: _SwapCardType.pay),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SwapChangeButton(),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SwapCard(type: _SwapCardType.receive),
                ),
              ],
            ),
            SwapAvailableBalance(),
            SwapFromToDropdown(type: _SwapDropdownType.to),
            Spacer(),
            SwapContinueButton(),
          ],
        ),
      ),
    );
  }
}

class SwapCard extends StatelessWidget {
  const SwapCard({super.key, required this.type});

  final _SwapCardType type;

  @override
  Widget build(BuildContext context) {
    final amount = _SwapCardType.pay == type ? '0 CAD' : '0 BTC';
    final convertionAmount =
        _SwapCardType.pay == type ? '~0.00 BTC' : '~0.00 CAD';

    return Container(
      height: 114,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colour.onPrimary,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: context.colour.secondaryFixedDim),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBText(
            'You ${type == _SwapCardType.pay ? 'Pay' : 'Receive'}',
            style: context.font.labelLarge,
            color: context.colour.outline,
          ),
          const Spacer(),
          IgnorePointer(
            ignoring: type == _SwapCardType.receive,
            child: BBInputText(
              style: context.font.displaySmall,
              value: amount,
              onChanged: (v) {},
            ),
          ),
          const Gap(4),
          BBText(convertionAmount, style: context.font.labelSmall),
        ],
      ),
    );
  }
}

class SwapChangeButton extends StatelessWidget {
  const SwapChangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.swap_vert),
      iconSize: 32,
      onPressed: () {},
    );
  }
}

class SwapAvailableBalance extends StatelessWidget {
  const SwapAvailableBalance({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    const balance = '53.00 BTC';
    const maxSelected = false;

    return Row(
      children: [
        BBText(
          'Available balance',
          style: context.font.labelLarge,
          color: context.colour.surface,
        ),
        const Gap(4),
        BBText('text', style: context.font.labelLarge),
        const Spacer(),
        BBButton.small(
          label: 'MAX',
          onPressed: () {},
          bgColor:
              maxSelected
                  ? context.colour.secondary
                  : context.colour.onSecondary,
          textColor:
              maxSelected
                  ? context.colour.onSecondary
                  : context.colour.secondary,
          outlined: true,
          borderColor:
              maxSelected
                  ? context.colour.onSecondary
                  : context.colour.secondary,
        ),
      ],
    );
  }
}

class SwapFromToDropdown extends StatelessWidget {
  const SwapFromToDropdown({super.key, required this.type});

  final _SwapDropdownType type;

  List<DropdownMenuItem<String>> _buildDropdownItems(
    BuildContext context,
    List<String> items,
  ) {
    return [
      for (final String item in items)
        DropdownMenuItem(
          value: item,
          child: BBText(item, style: context.font.headlineSmall),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final items = ['CAD', 'USD'];
    final dropdownItems = _buildDropdownItems(context, items);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBText(
          'Swap ${type == _SwapDropdownType.from ? 'from' : 'to'}',
          style: context.font.bodyLarge,
        ),
        const Gap(4),
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
                items: [...dropdownItems],
                onChanged: (value) {},
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SwapContinueButton extends StatelessWidget {
  const SwapContinueButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Continue',
      bgColor: context.colour.secondary,
      textColor: context.colour.onSecondary,
      onPressed: () {},
    );
  }
}
