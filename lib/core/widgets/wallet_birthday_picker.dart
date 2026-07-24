import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_birthday_checkpoint_failure.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// Reusable bottom sheet that lets a user narrow — or explicitly skip, via
/// the network's genesis block — the compact-block-filter recovery scan
/// range for a wallet about to be recovered from a mnemonic or a
/// RecoverBull vault.
///
/// Used by both onboarding mnemonic recovery
/// (`OnboardingPhysicalRecovery`) and RecoverBull (`FetchVaultKeyPage`),
/// which is why it lives here rather than under either feature's `ui/` —
/// see AGENTS.md's UI Kit workflow, step 3.
///
/// [onResolve] must call `ResolveWalletBirthdayCheckpointUsecase.execute`
/// with `lookupMode: WalletBirthdayLookupMode.recovery` — this widget only
/// owns the date pick and the retry/genesis-fallback UI around a single
/// resolve attempt, never the lookup-mode decision itself (that stays the
/// caller's business logic, per the use-case's own doc).
///
/// [WalletBirthdayPicker.show] resolves to `null` if the user backs out
/// (the close button, or dismissing the sheet) without a successfully
/// resolved checkpoint — the caller must treat that as a full cancellation
/// of the recovery attempt in progress, never proceed with a partially
/// resolved birthday.
class WalletBirthdayPicker extends StatefulWidget {
  const WalletBirthdayPicker({
    super.key,
    required this.isTestnet,
    required this.onResolve,
  });

  final bool isTestnet;
  final Future<
    Result<WalletBirthdayCheckpoint, WalletBirthdayCheckpointFailure>
  >
  Function(DateTime requestedBirthday)
  onResolve;

  static Future<WalletBirthdayCheckpoint?> show(
    BuildContext context, {
    required bool isTestnet,
    required Future<
      Result<WalletBirthdayCheckpoint, WalletBirthdayCheckpointFailure>
    >
    Function(DateTime requestedBirthday)
    onResolve,
  }) {
    return BlurredBottomSheet.show<WalletBirthdayCheckpoint>(
      context: context,
      child: WalletBirthdayPicker(isTestnet: isTestnet, onResolve: onResolve),
    );
  }

  @override
  State<WalletBirthdayPicker> createState() => _WalletBirthdayPickerState();
}

class _WalletBirthdayPickerState extends State<WalletBirthdayPicker> {
  late final BitcoinGenesisBlock _genesis = BitcoinGenesisBlock.forNetwork(
    isTestnet: widget.isTestnet,
  );

  // Defaults to the network's genesis block, per this widget's class doc —
  // resolving that instant is always a local, network-free lookup (see
  // `WalletBirthdayCheckpointRepositoryImpl`), so a user who never touches
  // the date picker gets the safest (full history scan) and fastest
  // (no HTTP round-trip) outcome without any extra action.
  late DateTime _selected = _genesis.timestamp;
  bool _isResolving = false;
  bool _hasFailure = false;

  bool get _isGenesisSelected => !_selected.isAfter(_genesis.timestamp);

  Future<void> _pickDate() async {
    if (_isResolving) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _isGenesisSelected ? now : _selected,
      firstDate: _genesis.timestamp,
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selected = picked;
      _hasFailure = false;
    });
  }

  Future<void> _resolve(DateTime requestedBirthday) async {
    setState(() {
      _isResolving = true;
      _hasFailure = false;
    });

    final result = await widget.onResolve(requestedBirthday);
    if (!mounted) return;

    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err():
        setState(() {
          _isResolving = false;
          _hasFailure = true;
        });
    }
  }

  void _useGenesis() {
    setState(() {
      _selected = _genesis.timestamp;
      _hasFailure = false;
    });
    unawaited(_resolve(_genesis.timestamp));
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;

    return PopScope(
      canPop: !_isResolving,
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: BBText(
                    loc.walletBirthdayPickerTitle,
                    style: context.font.headlineMedium,
                    color: context.appColors.onSurface,
                  ),
                ),
                IconButton(
                  tooltip: loc.closeDialogButton,
                  onPressed: _isResolving
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Gap(8),
            BBText(
              loc.walletBirthdayPickerBody,
              style: context.font.bodyMedium?.copyWith(height: 1.4),
              color: context.appColors.onSurfaceVariant,
            ),
            const Gap(20),
            BBText(
              loc.walletBirthdayPickerDateLabel,
              style: context.font.labelMedium,
              color: context.appColors.onSurfaceVariant,
            ),
            const Gap(8),
            InkWell(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: context.appColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: BBText(
                        _isGenesisSelected
                            ? loc.walletBirthdayPickerGenesisDateLabel
                            : MaterialLocalizations.of(
                                context,
                              ).formatShortDate(_selected),
                        style: context.font.bodyLarge,
                        color: context.appColors.onSurface,
                      ),
                    ),
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: context.appColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
            if (_hasFailure) ...[
              const Gap(16),
              BBText(
                loc.walletBirthdayPickerResolutionFailedMessage,
                style: context.font.bodyMedium,
                color: context.appColors.error,
              ),
              const Gap(12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isResolving ? null : _useGenesis,
                      child: BBText(
                        loc.walletBirthdayPickerUseGenesisButton,
                        style: context.font.labelLarge,
                      ),
                    ),
                  ),
                  const Gap(12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isResolving
                          ? null
                          : () => _resolve(_selected),
                      child: BBText(loc.retry, style: context.font.labelLarge),
                    ),
                  ),
                ],
              ),
            ],
            const Gap(24),
            BBButton.big(
              label: loc.walletBirthdayPickerContinueButton,
              onPressed: () => _resolve(_selected),
              disabled: _isResolving,
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
          ],
        ),
      ),
    );
  }
}
