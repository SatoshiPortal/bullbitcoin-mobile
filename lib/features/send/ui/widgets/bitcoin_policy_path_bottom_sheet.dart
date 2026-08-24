import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_option_tile.dart';
import 'package:bb_mobile/features/send/ui/widgets/bitcoin_policy_preimage_input.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class BitcoinPolicyPathBottomSheet extends StatefulWidget {
  const BitcoinPolicyPathBottomSheet({super.key});

  @override
  State<BitcoinPolicyPathBottomSheet> createState() =>
      _BitcoinPolicyPathBottomSheetState();
}

class _BitcoinPolicyPathBottomSheetState
    extends State<BitcoinPolicyPathBottomSheet> {
  BitcoinPolicySelection? _selection;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SendCubit>().state;
    final policy = state.bitcoinSigningPlan?.policy;
    if (policy == null) return const SizedBox.shrink();
    final selection =
        _selection ??
        state.bitcoinPolicySelection ??
        const BitcoinPolicySelection.empty();
    final selectors = policy.pathSelectors(selection);
    final requirements = policy.pathRequirements(selection);
    final requiredHashlocks = policy.requiredHashlocks(selection);
    final hasRequiredPreimages = requiredHashlocks.every(
      (hashlock) => state.satisfiedBitcoinPolicyPreimages.contains(
        '${hashlock.type.name}:${hashlock.hash.toLowerCase()}',
      ),
    );

    final showKeychain =
        selectors.any(
          (selector) => selector.keychain == BitcoinPolicyKeychain.external,
        ) &&
        selectors.any(
          (selector) => selector.keychain == BitcoinPolicyKeychain.internal,
        );
    final hasChoice = selectors.any(
      (selector) =>
          bitcoinPolicySelectorHasChoice(state, selector, selection: selection),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: BBText(
                  context.loc.sendAuthorizeTransaction,
                  style: context.font.headlineMedium,
                  color: context.appColors.secondary,
                ),
              ),
              Positioned(
                right: 0,
                child: IconButton(
                  tooltip: context.loc.closeDialogButton,
                  iconSize: 24,
                  icon: Icon(Icons.close, color: context.appColors.secondary),
                  onPressed: context.pop,
                ),
              ),
            ],
          ),
          if (hasChoice) ...[
            const Gap(16),
            BBText(
              context.loc.sendChooseAuthorizationDescription,
              style: context.font.bodyMedium,
              color: context.appColors.textMuted,
              textAlign: TextAlign.center,
            ),
            const Gap(24),
          ] else
            const Gap(24),
          if (selectors.isEmpty && state.requiresBitcoinPolicySelection)
            BBText(
              context.loc.sendPolicyNoPathAvailable,
              style: context.font.bodyMedium,
              color: context.appColors.textMuted,
              textAlign: TextAlign.center,
            ),
          for (final (selectorIndex, selector) in selectors.indexed) ...[
            Padding(
              padding: EdgeInsets.only(
                left: _selectorIndent(selector.nodePath),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (showKeychain ||
                      selector.keychain == BitcoinPolicyKeychain.internal) ...[
                    BBText(
                      selector.keychain == BitcoinPolicyKeychain.external
                          ? context.loc.sendPolicyReceivePath
                          : context.loc.sendPolicyChangePath,
                      style: context.font.labelMedium,
                      color: context.appColors.textMuted,
                    ),
                    const Gap(4),
                  ],
                  if (bitcoinPolicySelectorHasChoice(
                    state,
                    selector,
                    selection: selection,
                  )) ...[
                    BBText(
                      bitcoinPolicySelectorInstruction(context, selector),
                      style: context.font.bodyLarge?.copyWith(
                        fontWeight: .w500,
                      ),
                      color: context.appColors.secondary,
                    ),
                    const Gap(12),
                  ],
                  for (final (optionIndex, option)
                      in selector.options.indexed) ...[
                    BitcoinPolicyOptionTile(
                      selector: selector,
                      optionIndex: optionIndex,
                      option: option,
                      wallet: state.selectedWallet,
                      selection: selection,
                      onSelectedIndicesChanged: (selectedIndices) {
                        setState(() {
                          _selection = policy.select(
                            current: selection,
                            requirement: selector,
                            selectedIndices: selectedIndices,
                          );
                        });
                      },
                    ),
                    if (optionIndex != selector.options.length - 1)
                      const Gap(8),
                  ],
                ],
              ),
            ),
            if (selectorIndex != selectors.length - 1) const Gap(24),
          ],
          for (final hashlock in requiredHashlocks) ...[
            if (selectors.isNotEmpty) const Gap(24),
            BitcoinPolicyPreimageInput(
              key: ValueKey('${hashlock.type.name}:${hashlock.hash}'),
              hashlock: hashlock,
            ),
          ],
          if (state.nextBitcoinPolicyActivation case final activation?
              when selectors.isEmpty) ...[
            const Gap(24),
            _PolicyActivationNotice(activation: activation),
          ],
          const Gap(24),
          BBButton.big(
            label: context.loc.sendDone,
            onPressed: () async {
              final cubit = context.read<SendCubit>();
              final restartSelection = await cubit.applyBitcoinPolicySelection(
                selection,
              );
              if (!context.mounted) return;
              if (restartSelection != null) {
                final restart = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.loc.sendRestartSigningTitle),
                    content: Text(context.loc.sendRestartSigningDescription),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(context.loc.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(context.loc.sendRestartSigningConfirm),
                      ),
                    ],
                  ),
                );
                if (restart != true || !context.mounted) return;
                await cubit.restartBitcoinSigningForPathChange(
                  restartSelection,
                );
              }
              if (context.mounted) context.pop();
            },
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
            disabled:
                requirements.isNotEmpty ||
                !state.bitcoinPolicySelectionIsAvailable(selection) ||
                !hasRequiredPreimages,
          ),
          const Gap(24),
        ],
      ),
    );
  }
}

double _selectorIndent(String nodePath) {
  final depth = nodePath.split('/').length - 1;
  return 16.0 * (depth > 3 ? 3 : depth);
}

class _PolicyActivationNotice extends StatelessWidget {
  final BitcoinPolicyActivation activation;

  const _PolicyActivationNotice({required this.activation});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(Icons.schedule, size: 20, color: context.appColors.textMuted),
      const Gap(8),
      Expanded(
        child: BBText(
          describeBitcoinPolicyActivation(context, activation),
          style: context.font.bodySmall,
          color: context.appColors.textMuted,
          maxLines: 3,
        ),
      ),
    ],
  );
}
