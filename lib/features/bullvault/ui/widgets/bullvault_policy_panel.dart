import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/widgets/bitcoin_policy_condition.dart';
import 'package:bb_mobile/core/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/features/bullvault/domain/entities/bullvault_inspection.dart';
import 'package:bb_mobile/features/bullvault/ui/widgets/bullvault_key_summary.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bull_ui/bull_ui.dart' show BullBorderedTile, Gap;
import 'package:flutter/material.dart';

class BullVaultPolicyPanel extends StatelessWidget {
  final BullVaultInspection inspection;
  const BullVaultPolicyPanel({super.key, required this.inspection});
  @override
  Widget build(BuildContext context) => WalletPolicyView(
    walletId: inspection.wallet.id,
    builder: (context, policy) =>
        BullVaultPolicyDetails(inspection: inspection, policy: policy),
  );
}

class BullVaultPolicyDetails extends StatelessWidget {
  final BullVaultInspection inspection;
  final BitcoinWalletPolicy policy;
  const BullVaultPolicyDetails({
    super.key,
    required this.inspection,
    required this.policy,
  });
  @override
  Widget build(BuildContext context) {
    final root = policy.external.root;
    final paths =
        root is BitcoinThresholdPolicyNode &&
            root.requiresSelection &&
            root.threshold == 1
        ? root.children
        : [root];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, path) in paths.indexed)
          _Stage(
            inspection: inspection,
            node: path,
            index: index,
            last: index == paths.length - 1,
          ),
        if (paths.length > 1)
          Text(
            context.loc.walletPolicyEarlierOptions,
            style: context.font.bodySmall?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
      ],
    );
  }
}

List<BitcoinSignaturePolicyNode>? _signatures(BitcoinPolicyNode node) =>
    switch (node) {
      BitcoinSignaturePolicyNode() => [node],
      BitcoinThresholdPolicyNode(:final children)
          when children.every((child) => child is BitcoinSignaturePolicyNode) =>
        children.cast<BitcoinSignaturePolicyNode>(),
      _ => null,
    };

class _Stage extends StatelessWidget {
  final BullVaultInspection inspection;
  final BitcoinPolicyNode node;
  final int index;
  final bool last;
  const _Stage({
    required this.inspection,
    required this.node,
    required this.index,
    required this.last,
  });

  String _name(BuildContext context, BitcoinPolicyKey key) {
    final signer = inspection.signerForKey(key);
    return signer == null
        ? context.loc.walletDetailsUnavailableLabel
        : bullVaultSignerName(context, inspection, signer, policyKey: key);
  }

  Widget _key(BuildContext context, BitcoinSignaturePolicyNode node) {
    final signer = inspection.signerForKey(node.key);
    return signer == null
        ? Text(context.loc.walletDetailsUnavailableLabel)
        : BullVaultKeySummary(
            inspection: inspection,
            signer: signer,
            policyKey: node.key,
          );
  }

  Widget _row(BuildContext context, List<BitcoinSignaturePolicyNode> keys) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = keys.length == 2 && constraints.maxWidth >= 270;
          return Flex(
            direction: horizontal ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: horizontal
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              for (final (index, key) in keys.indexed) ...[
                if (index > 0)
                  const Padding(padding: EdgeInsets.all(8), child: Text('+')),
                if (horizontal)
                  Expanded(child: _key(context, key))
                else
                  _key(context, key),
              ],
            ],
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    var rule = node;
    BitcoinAbsoluteTimelockPolicyNode? clock;
    // The header replaces exactly one AND condition, never an OR or mixed rule.
    if (node case BitcoinThresholdPolicyNode(
      threshold: 2,
      children: [final first, final second],
    )) {
      if (first is BitcoinAbsoluteTimelockPolicyNode &&
          _signatures(second) != null) {
        clock = first;
        rule = second;
      } else if (second is BitcoinAbsoluteTimelockPolicyNode &&
          _signatures(first) != null) {
        clock = second;
        rule = first;
      }
    }
    final signatures = _signatures(rule);
    final count = rule is BitcoinThresholdPolicyNode ? rule.threshold : 1;
    final fromStart = signatures != null && clock == null;
    final emphasized = fromStart && index == 0;
    final color = emphasized
        ? context.appColors.surface
        : context.appColors.onSurface;
    final title = signatures == null
        ? context.loc.walletDetailsSpendingConditionsLabel
        : signatures.length == 1
        ? context.loc.walletPolicyKeyAlone(
            _name(context, signatures.single.key),
          )
        : count < signatures.length
        ? context.loc.walletPolicyAnyKeys(count)
        : signatures.map((key) => _name(context, key.key)).join(' + ');
    final timing = clock == null
        ? fromStart
              ? context.loc.walletPolicyFromStart
              : context.loc.walletDetailsSpendingPathTitle(index + 1)
        : clock.type == BitcoinAbsoluteTimelockType.blockHeight
        ? context.loc.walletPolicyAfterBlock(clock.value)
        : context.loc.walletPolicyFromDate(_timestamp(context, clock.value));
    return Stack(
      key: ValueKey('policy-timeline-${node.id}'),
      children: [
        Positioned(
          top: index == 0 ? 8 : 0,
          bottom: last ? 24 : 0,
          left: 4,
          width: 1,
          child: ColoredBox(color: context.appColors.border),
        ),
        Positioned(
          top: 4,
          left: 0,
          child: Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: emphasized
                  ? context.appColors.primary
                  : context.appColors.surface,
              border: Border.all(color: context.appColors.primary),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 22, bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (index + 1).toString().padLeft(2, '0'),
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: Text(
                      timing,
                      style: context.font.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: context.appColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const Gap(16),
              BullBorderedTile(
                backgroundColor: emphasized
                    ? context.appColors.onSurface
                    : context.appColors.surface,
                padding: const EdgeInsets.all(16),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: color),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: context.font.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      if (signatures != null) ...[
                        const Gap(8),
                        Text(
                          context.loc.walletPolicySignatureCount(count),
                          style: context.font.bodySmall?.copyWith(color: color),
                        ),
                      ],
                      const Gap(20),
                      if (signatures == null)
                        BitcoinPolicyCondition(
                          node: rule,
                          textColor: color,
                          describe: (node) {
                            if (node is BitcoinSignaturePolicyNode) {
                              final signer = inspection.signerForKey(node.key);
                              final access = signer == null
                                  ? BullVaultKeyAccess.unavailable
                                  : inspection.accessForSigner(
                                      signer,
                                      policyKey: node.key,
                                    );
                              return '${context.loc.walletPolicySignWith(_name(context, node.key))} · ${bullVaultKeyAccessLabel(context, access)}';
                            }
                            return describeBitcoinPolicyNode(
                              context,
                              node,
                              null,
                              summarizeConjunctions: true,
                            );
                          },
                        )
                      else if (count == 2 && signatures.length == 3)
                        for (final pair in [(0, 1), (0, 2), (1, 2)])
                          Container(
                            key: ValueKey(
                              '${rule.id}-combination-${pair.$1}-${pair.$2}',
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: context.appColors.border,
                                ),
                              ),
                            ),
                            child: _row(context, [
                              signatures[pair.$1],
                              signatures[pair.$2],
                            ]),
                          )
                      else if (count == signatures.length)
                        _row(context, signatures)
                      else
                        for (final key in signatures)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _key(context, key),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _timestamp(BuildContext context, int seconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      seconds * 1000,
      isUtc: true,
    ).toLocal();
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatMediumDate(date)} ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';
  }
}
