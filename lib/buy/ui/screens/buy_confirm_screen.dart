import 'package:bb_mobile/_ui/components/buttons/button.dart';
import 'package:bb_mobile/_ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/_ui/components/text/text.dart';
import 'package:bb_mobile/_ui/themes/app_theme.dart';
import 'package:bb_mobile/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class BuyConfirmScreen extends StatelessWidget {
  const BuyConfirmScreen({super.key});

  Widget _divider(BuildContext context) {
    return Container(
      height: 1,
      color: context.colour.secondaryFixedDim,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Buy Bitcoin',
          onBack: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.colour.secondaryFixedDim,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  Assets.icons.btc.path,
                ),
              ),
            ),
            const Gap(13),
            Center(
              child: BBText(
                '1000 CAD',
                style: context.font.displaySmall,
                color: context.colour.outlineVariant,
              ),
            ),
            const Gap(32),
            _buildDetailRow(context, 'You pay', '1000 CAD'),
            // _divider(context),
            _buildDetailRow(context, 'You receive', '0.00000786 BTC'),
            // _divider(context),
            _buildDetailRow(context, 'Bitcoin Price', '134 234 CAD'),
            // _divider(context),
            _buildDetailRow(context, 'Payout method', 'Secure Bitcoin Wallet'),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                BBText(
                  'Awaiting confirmation',
                  style: context.font.bodyMedium,
                  color: context.colour.outline,
                ),
                const Gap(8),
                BBText(
                  '04:34',
                  style: context.font.bodyMedium,
                  color: context.colour.primary,
                ),
              ],
            ),
            const Gap(16),
            BBButton.big(
              label: 'Confirm purchase',
              onPressed: () {},
              bgColor: context.colour.secondary,
              textColor: context.colour.onPrimary,
            ),
            const Gap(32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    bool isError = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            label,
            style: context.font.bodyMedium
                ?.copyWith(color: context.colour.surfaceContainer),
          ),
          const Spacer(),
          Expanded(
            child: BBText(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              style: context.font.bodyMedium
                  ?.copyWith(color: isError ? context.colour.primary : null),
            ),
          ),
        ],
      ),
    );
  }
}
