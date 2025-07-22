import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/transaction/domain/entities/tx.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

class TransactionDetailsWidget extends StatelessWidget {
  static const int _txidCut = 10;

  final RawBitcoinTxEntity tx;

  const TransactionDetailsWidget({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const Gap(16),
          _buildTransactionInfo(context),
          const Gap(16),
          _buildInputsSection(context),
          const Gap(16),
          _buildOutputsSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return _buildCard(
      context,
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt_long, color: context.colour.primary),
              const Gap(8),
              BBText(
                'Transaction ID',
                style: context.font.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Gap(8),
          GestureDetector(
            onTap: () => Clipboard.setData(ClipboardData(text: tx.txid)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.colour.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BBText(
                    '${tx.txid.substring(0, _txidCut)}…${tx.txid.substring(tx.txid.length - _txidCut)}',
                    style: context.font.bodySmall?.copyWith(
                      color: context.colour.primary,
                    ),
                  ),
                  const Gap(4),
                  Icon(Icons.copy, size: 12, color: context.colour.primary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionInfo(BuildContext context) {
    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            'Info',
            style: context.font.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(12),
          _buildInfoRow(context, 'Version', tx.version.toString()),
          _buildInfoRow(context, 'Size', '${tx.size} bytes'),
          _buildInfoRow(context, 'Virtual Size', '${tx.vsize} vbytes'),
          _buildInfoRow(context, 'Locktime', tx.locktime.toString()),
        ],
      ),
    );
  }

  Widget _buildInputsSection(BuildContext context) {
    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            Icons.input,
            'Inputs (${tx.vin.length})',
          ),
          const Gap(12),
          ...tx.vin.asMap().entries.map((entry) {
            final input = entry.value;
            return _buildItemContainer(
              context,
              index: input.vout ?? 0,
              color: context.colour.primary,
              child: BBText(
                input.txid != null
                    ? '${input.txid!.substring(0, _txidCut)}…${input.txid!.substring(input.txid!.length - _txidCut)}'
                    : 'Coinbase',
                style: context.font.bodyMedium,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildOutputsSection(BuildContext context) {
    return _buildCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            Icons.output,
            'Outputs (${tx.vout.length})',
          ),
          const Gap(12),
          ...tx.vout.asMap().entries.map((entry) {
            final index = entry.key;
            final output = entry.value;
            return _buildItemContainer(
              context,
              index: index,
              color: context.colour.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    '${output.value} sats',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.colour.primary,
                    ),
                  ),
                  BBText(
                    'Script: ${output.scriptPubKey.bytes.take(8).map((b) => b.toRadixString(16).padLeft(2, '0')).join('')}…',
                    style: context.font.bodySmall,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    Widget? child,
    double elevation = 1,
  }) {
    return Card(
      elevation: elevation,
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    IconData icon,
    String title,
  ) {
    return Row(
      children: [
        Icon(icon, color: context.colour.primary, size: 20),
        const Gap(8),
        BBText(
          title,
          style: context.font.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildItemContainer(
    BuildContext context, {
    required int index,
    required Color color,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colour.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.colour.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: BBText(index.toString(), style: context.font.bodySmall),
            ),
          ),
          const Gap(12),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: BBText(label, style: context.font.bodyMedium),
          ),
          const Gap(16),
          Expanded(child: BBText(value, style: context.font.bodyMedium)),
        ],
      ),
    );
  }
}
