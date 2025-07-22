import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SellInvoiceScreen extends StatelessWidget {
  const SellInvoiceScreen({super.key});

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: BBText(
                'Please pay this invoice',
                style: context.font.headlineMedium,
              ),
            ),
            Center(
              child: BBText(
                'Price will refresh in 04:34',
                style: context.font.bodyMedium,
                color: context.colour.outline,
              ),
            ),
            const Gap(32),
            const CopyInput(text: '0.00006823 BTC'),

            const Gap(32),
            const CopyInput(text: 'BC1QYL7J673.6Y6ALV70ASDASDMO'),

            const Gap(32),
            Container(
              height: 1,
              width: double.infinity,
              color: context.colour.secondaryFixedDim,
            ),
            const Gap(16),
            _buildDetailRow(context, 'Recipient name', 'Theo Mogenet'),
            const Gap(8),
            _buildDetailRow(
              context,
              'SEPA number',
              '123123213213123123123123\n123123123121231231231233',
            ),
            const Gap(8),
            _buildDetailRow(context, 'Memo', 'Add public memo', isError: true),
            const Gap(8),
            _buildDetailRow(context, 'Bitcoin amount', '0.0006823 BTC'),
            const Gap(8),
            _buildDetailRow(context, 'Payout amount', '1000 CAD'),
            const Gap(8),
            _buildDetailRow(context, 'Bitcoin Price', '96,234.32 CAD'),
            const Gap(8),
            _buildDetailRow(context, 'Order Number', '543678990'),
            // const Spacer(),
            const Gap(48),
            Row(
              children: [
                Expanded(
                  child: BBButton.big(
                    label: 'Copy invoice',
                    onPressed: () {},
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                  ),
                ),
                const Gap(16),
                Expanded(
                  child: BBButton.big(
                    label: 'Show QR code',
                    bgColor: Colors.transparent,
                    textColor: context.colour.secondary,
                    outlined: true,
                    borderColor: context.colour.secondary,
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            const Gap(16),
            BBButton.big(
              label: 'Pay with Bull wallet',
              onPressed: () {},
              bgColor: context.colour.secondary,
              textColor: context.colour.onPrimary,
            ),
            const Gap(40),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
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
                color: isError ? context.colour.error : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
