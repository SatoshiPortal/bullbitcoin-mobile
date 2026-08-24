import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/tiles/bordered_tappable_tile.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_description.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitcoinPolicyOptionTile extends StatefulWidget {
  final BitcoinPolicyPathRequirement selector;
  final int optionIndex;
  final BitcoinPolicyNode option;
  final Wallet? wallet;
  final BitcoinPolicySelection selection;
  final ValueChanged<Set<int>> onSelectedIndicesChanged;

  const BitcoinPolicyOptionTile({
    super.key,
    required this.selector,
    required this.optionIndex,
    required this.option,
    required this.wallet,
    required this.selection,
    required this.onSelectedIndicesChanged,
  });

  @override
  State<BitcoinPolicyOptionTile> createState() =>
      _BitcoinPolicyOptionTileState();
}

class _BitcoinPolicyOptionTileState extends State<BitcoinPolicyOptionTile> {
  var _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final selectedIndices =
        widget.selection.choiceFor(
          keychain: widget.selector.keychain,
          nodePath: widget.selector.nodePath,
        ) ??
        const [];
    final availableSelectedIndices = selectedIndices.where(
      (index) => state
          .bitcoinPolicyOptionStatus(
            requirement: widget.selector,
            optionIndex: index,
            selection: widget.selection,
          )
          .available,
    );
    final selected = availableSelectedIndices.contains(widget.optionIndex);
    final status = state.bitcoinPolicyOptionStatus(
      requirement: widget.selector,
      optionIndex: widget.optionIndex,
      selection: widget.selection,
    );
    final hasChoice = bitcoinPolicySelectorHasChoice(
      state,
      widget.selector,
      selection: widget.selection,
    );
    final summary = describeBitcoinPolicyAuthorization(
      context,
      widget.option,
      widget.wallet,
    );
    final details = describeBitcoinPolicyNode(
      context,
      widget.option,
      widget.wallet,
    );
    final hasDetails =
        widget.option is BitcoinThresholdPolicyNode || summary != details;
    final statusText = describeBitcoinPolicyOptionStatus(
      context,
      state,
      widget.option,
      status,
    );
    return Semantics(
      button: hasChoice,
      enabled: status.available && hasChoice,
      checked: hasChoice ? selected : null,
      child: BorderedTappableTile(
        onTap: !status.available || !hasChoice
            ? null
            : () {
                final updated = availableSelectedIndices.toSet();
                if (widget.selector.threshold == 1) {
                  updated
                    ..clear()
                    ..add(widget.optionIndex);
                } else if (selected) {
                  updated.remove(widget.optionIndex);
                } else if (updated.length < widget.selector.threshold) {
                  updated.add(widget.optionIndex);
                }
                widget.onSelectedIndicesChanged(updated);
              },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    summary,
                    style: context.font.bodyMedium?.copyWith(fontWeight: .w500),
                    color: status.available
                        ? context.appColors.secondary
                        : context.appColors.textMuted,
                  ),
                  const Gap(4),
                  BBText(
                    statusText,
                    style: context.font.bodySmall,
                    color: status.available
                        ? context.appColors.textMuted
                        : context.appColors.error,
                  ),
                  if (hasDetails) ...[
                    const Gap(8),
                    Semantics(
                      button: true,
                      expanded: _showDetails,
                      child: InkWell(
                        onTap: () => setState(() {
                          _showDetails = !_showDetails;
                        }),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BBText(
                              _showDetails
                                  ? context.loc.sendPolicyHideDetails
                                  : context.loc.sendPolicyViewDetails,
                              style: context.font.bodySmall?.copyWith(
                                fontWeight: .w500,
                              ),
                              color: context.appColors.primary,
                            ),
                            const Gap(2),
                            Icon(
                              _showDetails
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: context.appColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_showDetails) ...[
                      const Gap(6),
                      if (widget.option
                          case final BitcoinThresholdPolicyNode node)
                        _BitcoinPolicyThresholdDetails(
                          node: node,
                          wallet: widget.wallet,
                        )
                      else
                        BBText(
                          details,
                          style: context.font.bodySmall,
                          color: context.appColors.textMuted,
                        ),
                    ],
                  ],
                ],
              ),
            ),
            const Gap(12),
            Icon(
              !status.available
                  ? Icons.lock_outline
                  : !hasChoice
                  ? Icons.check_circle
                  : widget.selector.threshold == 1
                  ? selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off
                  : selected
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: status.available && (selected || !hasChoice)
                  ? context.appColors.primary
                  : context.appColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BitcoinPolicyThresholdDetails extends StatelessWidget {
  final BitcoinThresholdPolicyNode node;
  final Wallet? wallet;

  const _BitcoinPolicyThresholdDetails({
    required this.node,
    required this.wallet,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (index, child) in node.children.indexed) ...[
        _BitcoinPolicyConditionDetail(node: child, wallet: wallet),
        if (index != node.children.length - 1) const Gap(8),
      ],
    ],
  );
}

class _BitcoinPolicyConditionDetail extends StatelessWidget {
  final BitcoinPolicyNode node;
  final Wallet? wallet;

  const _BitcoinPolicyConditionDetail({required this.node, this.wallet});

  @override
  Widget build(BuildContext context) => Row(
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
            BBText(
              describeBitcoinPolicyNode(context, node, wallet),
              style: context.font.bodySmall,
              color: context.appColors.textMuted,
            ),
            if (node case final BitcoinThresholdPolicyNode threshold) ...[
              const Gap(8),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: _BitcoinPolicyThresholdDetails(
                  node: threshold,
                  wallet: wallet,
                ),
              ),
            ],
          ],
        ),
      ),
    ],
  );
}
