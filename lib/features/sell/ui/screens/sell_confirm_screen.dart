import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SellConfirmScreen extends StatelessWidget {
  const SellConfirmScreen({super.key});

  Widget _divider(BuildContext context) {
    return Container(height: 1, color: context.colour.secondaryFixedDim);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: '',
          bullLogo: true,
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
              child: BBText(
                'Confirm payment',
                style: context.font.headlineMedium,
              ),
            ),
            const Gap(32),
            _buildDetailRow(context, 'Payin amount', '0.00000786 BTC'),
            _divider(context),
            _buildDetailRow(context, 'Payout amount', '1000 CAD'),
            _divider(context),
            _buildDetailRow(context, 'Payout recipient', '04:34'),
            _divider(context),
            _buildDetailRow(context, 'From', 'Secure Bitcoin wallet'),
            _divider(context),
            _buildDetailRow(context, 'Network fees', '1000 sats'),
            _divider(context),
            _buildDetailRow(context, 'Fee Priority', 'Fastest', isError: true),
            const Spacer(),
            BBButton.big(
              label: 'Advanced Settings',
              onPressed: () {},
              bgColor: Colors.transparent,
              textColor: context.colour.secondary,
              outlined: true,
              borderColor: context.colour.secondary,
            ),
            const Gap(16),
            BBButton.big(
              label: 'Confirm',
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
            style: context.font.bodyMedium?.copyWith(
              color: context.colour.surfaceContainer,
            ),
          ),
          const Spacer(),
          Expanded(
            child: BBText(
              value,
              textAlign: TextAlign.end,
              maxLines: 2,
              style: context.font.bodyMedium?.copyWith(
                color: isError ? context.colour.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
