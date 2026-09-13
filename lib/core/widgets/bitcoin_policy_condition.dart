import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bull_ui/bull_ui.dart' show BullText, Gap;
import 'package:flutter/material.dart';

class BitcoinPolicyCondition extends StatelessWidget {
  final BitcoinPolicyNode node;
  final String Function(BitcoinPolicyNode) describe;
  final Color textColor;
  final TextStyle? textStyle;
  final bool showSignatureCombinations;

  /// Compact signer rows when the caller already displays the threshold.
  /// Other conditions always retain the complete tree presentation.
  final bool compactSignatures;

  /// Optional signer presentation, shared by leaves and signature combinations.
  final Widget Function(BuildContext context, BitcoinPolicyKey key)?
  signerBuilder;

  const BitcoinPolicyCondition({
    super.key,
    required this.node,
    required this.describe,
    required this.textColor,
    this.textStyle,
    this.showSignatureCombinations = false,
    this.compactSignatures = false,
    this.signerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (compactSignatures) {
      if (node is BitcoinSignaturePolicyNode) {
        return _description(context, node);
      }
      if (node case BitcoinThresholdPolicyNode(
        :final children,
        :final threshold,
      ) when children.every((child) => child is BitcoinSignaturePolicyNode)) {
        if (showSignatureCombinations &&
            threshold == 2 &&
            children.length == 3) {
          return _combinations(context, children);
        }
        if (threshold == children.length) {
          return _signatureRow(context, children);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              _description(context, child),
              if (index != children.length - 1) const Gap(12),
            ],
          ],
        );
      }
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: context.appColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const Gap(10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _description(context, node),
              if (node case BitcoinThresholdPolicyNode(
                :final children,
                :final threshold,
              )) ...[
                const Gap(8),
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showSignatureCombinations &&
                          threshold == 2 &&
                          children.length == 3 &&
                          children.every(
                            (child) => child is BitcoinSignaturePolicyNode,
                          ))
                        _combinations(context, children)
                      else
                        for (final (index, child) in children.indexed) ...[
                          BitcoinPolicyCondition(
                            node: child,
                            describe: describe,
                            textColor: textColor,
                            textStyle: textStyle,
                            showSignatureCombinations:
                                showSignatureCombinations,
                            signerBuilder: signerBuilder,
                          ),
                          if (index != children.length - 1) const Gap(8),
                        ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _combinations(
    BuildContext context,
    List<BitcoinPolicyNode> children,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (first, second) in [(0, 1), (0, 2), (1, 2)])
        Container(
          key: ValueKey('${node.id}-combination-$first-$second'),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: context.appColors.border)),
          ),
          child: _signatureRow(context, [children[first], children[second]]),
        ),
    ],
  );

  Widget _signatureRow(
    BuildContext context,
    List<BitcoinPolicyNode> children,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final horizontal = children.length == 2 && constraints.maxWidth >= 270;
      return Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        crossAxisAlignment: horizontal
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              Padding(
                padding: const EdgeInsets.all(8),
                child: BullText(
                  '+',
                  style: textStyle ?? context.font.bodySmall,
                  color: textColor,
                ),
              ),
            if (horizontal)
              Expanded(child: _description(context, child))
            else
              _description(context, child),
          ],
        ],
      );
    },
  );

  Widget _description(BuildContext context, BitcoinPolicyNode node) {
    if (node is BitcoinSignaturePolicyNode && signerBuilder != null) {
      return DefaultTextStyle.merge(
        style: (textStyle ?? context.font.bodySmall)?.copyWith(
          color: textColor,
        ),
        child: Builder(builder: (context) => signerBuilder!(context, node.key)),
      );
    }
    return BullText(
      describe(node),
      style: textStyle ?? context.font.bodySmall,
      color: textColor,
    );
  }
}
