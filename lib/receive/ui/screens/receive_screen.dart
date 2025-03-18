import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/inputs/copy_input.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/segment/segmented_full.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Receive',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: const SingleChildScrollView(
        child: QrPage(),
      ),
    );
  }
}

class QrPage extends StatelessWidget {
  const QrPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(10),
        ReceiveNetworkSelection(),
        Gap(16),
        ReceiveQRDetails(),
        Gap(10),
        ReceiveInfoDetails(),
        Gap(16),
        ReceiveCopyAddress(),
        Gap(10),
        ReceiveButton(),
        Gap(40),
      ],
    );
  }
}

class AmountPage extends StatelessWidget {
  const AmountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Gap(20),
        ReceiveNetworkSelection(),
        Gap(16),
        ReceiveAmountEntry(),
        Gap(10),
        ReceiveBalanceRow(),
        ReceiveNumberPad(),
        Gap(60),
        ReceiveButton(),
      ],
    );
  }
}

class ReceiveNetworkSelection extends StatelessWidget {
  const ReceiveNetworkSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BBSwitcher<String>(
        items: const {
          'Bitcoin',
          'Lightning',
          'Liquid',
        },
        onSelected: (c) {},
        selected: 'Bitcoin',
      ),
    );
  }
}

class ReceiveQRDetails extends StatelessWidget {
  const ReceiveQRDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 42),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(data: 'BC1QYL7J673.6Y6ALV70ASDASDM0'),
          ),
        ),
        const Gap(14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BBText(
                'Address',
                style: context.font.bodyMedium,
              ),
              const Gap(6),
              const CopyInput(text: 'BC1QYL7J673.6Y6ALV70ASDASDM0'),
            ],
          ),
        ),
      ],
    );
  }
}

class ReceiveInfoDetails extends StatelessWidget {
  const ReceiveInfoDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: context.colour.surface),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                top: 12,
                bottom: 10,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        'Amount',
                        style: context.font.labelSmall,
                        color: context.colour.outline,
                      ),
                      const Gap(4),
                      Row(
                        children: [
                          BBText(
                            '0 sats',
                            style: context.font.bodyMedium,
                          ),
                          const Gap(12),
                          BBText(
                            '~0.00 CAD',
                            style: context.font.bodyLarge,
                            color: context.colour.outline,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
            Container(color: context.colour.surface, height: 1),
            Padding(
              padding: const EdgeInsets.only(
                left: 8,
                right: 8,
                top: 10,
                bottom: 12,
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        'Note',
                        style: context.font.labelSmall,
                        color: context.colour.outline,
                      ),
                      const Gap(4),
                      BBText(
                        'Enter here...',
                        style: context.font.bodyMedium,
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                    icon: const Icon(Icons.edit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReceiveCopyAddress extends StatelessWidget {
  const ReceiveCopyAddress({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16 + 12),
      child: Row(
        children: [
          BBText(
            'Copy or scan address only',
            style: context.font.headlineSmall,
          ),
          const Spacer(),
          Switch(
            inactiveTrackColor: context.colour.surface,
            trackOutlineWidth: const WidgetStatePropertyAll(0),
            inactiveThumbColor: context.colour.onPrimary,
            padding: EdgeInsets.zero,
            value: false,
            thumbIcon: WidgetStatePropertyAll(
              Icon(
                Icons.circle,
                color: context.colour.onPrimary,
              ),
            ),
            onChanged: (v) {},
          ),
        ],
      ),
    );
  }
}

class ReceiveAmountEntry extends StatelessWidget {
  const ReceiveAmountEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ReceiveNumberPad extends StatelessWidget {
  const ReceiveNumberPad({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ReceiveBalanceRow extends StatelessWidget {
  const ReceiveBalanceRow({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ReceiveButton extends StatelessWidget {
  const ReceiveButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: BBButton.big(
        label: 'New address',
        onPressed: () {},
        bgColor: context.colour.secondary,
        textColor: context.colour.onSecondary,
      ),
    );
  }
}
