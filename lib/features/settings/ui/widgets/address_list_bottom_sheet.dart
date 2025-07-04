import 'package:bb_mobile/features/settings/ui/widgets/address_card.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class AddressListBottomSheet extends StatelessWidget {
  const AddressListBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    // This widget is a placeholder for the address list bottom sheet.
    // You can implement the actual UI and functionality here.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(8),
            Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Center(
                  child: Text(
                    'Addresses',
                    style: context.font.headlineMedium?.copyWith(
                      color: context.colour.secondary,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(24),
            ListView.separated(
              separatorBuilder: (context, index) => const Gap(16),
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 10,
              shrinkWrap: true,
              itemBuilder: (context, index) {
                return AddressCard(
                  isUsed: index.isEven,
                  address: 'bc1q${'a' * 40}',
                  index: index,
                  balanceSat: index * 1000,
                );
              },
            ),
            const Gap(24),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: 'Receive',
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                    onPressed: () {},
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    label: 'Change',
                    bgColor: context.colour.secondary,
                    textColor: context.colour.onSecondary,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
