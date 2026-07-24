import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/cards/info_card.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/domain/import_watch_only_failure.dart';
import 'package:bb_mobile/features/labels/ui/labeled_text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:satoshifier/enums/derivation.dart' as satoshifier;

class WatchOnlyDetailsWidget extends StatelessWidget {
  final WatchOnlyWalletEntity watchOnlyWallet;
  const WatchOnlyDetailsWidget({super.key, required this.watchOnlyWallet});

  @override
  Widget build(BuildContext context) {
    return watchOnlyWallet.when(
      descriptor: (_, _, _) => const _DescriptorDetailsWidget(),
      xpub: (_, _, _) => const _XpubDetailsWidget(),
    );
  }
}

class _DescriptorDetailsWidget extends StatelessWidget {
  const _DescriptorDetailsWidget();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final watchOnlyWallet = context
        .watch<ImportWatchOnlyCubit>()
        .state
        .watchOnlyWallet;
    final entity = watchOnlyWallet! as WatchOnlyDescriptorEntity;

    return Column(
      crossAxisAlignment: .start,
      children: [
        LabeledTextInput(
          label: context.loc.importWatchOnlyDescriptor,
          value: entity.descriptor.combined,
          onChanged: null,
        ),
        const Gap(24),
        LabeledTextInput(
          label: context.loc.importWatchOnlyType,
          value: entity.descriptor.derivation.label,
          onChanged: null,
        ),
        const Gap(24),
        if (entity.signerDevice == null)
          Row(
            children: [
              SizedBox(
                width: 120,
                child: BBText(
                  context.loc.importWatchOnlySigningDevice,
                  style: context.font.titleMedium,
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<SignerDeviceEntity?>(
                  alignment: Alignment.centerLeft,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
                  ),
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: context.appColors.text,
                  ),
                  initialValue: entity.signerDevice,
                  items: [null, ...SignerDeviceEntity.values]
                      .map(
                        (value) => DropdownMenuItem<SignerDeviceEntity?>(
                          value: value,
                          child: BBText(
                            value?.displayName ??
                                context.loc.importWatchOnlyUnknown,
                            style: context.font.headlineSmall,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: cubit.onSignerDeviceChanged,
                ),
              ),
            ],
          ),
        if (entity.signerDevice != null)
          LabeledTextInput(
            label: context.loc.importWatchOnlySigningDevice,
            value: entity.signerDevice!.displayName,
            onChanged: null,
          ),
        const Gap(24),
        LabeledTextInput(
          label: context.loc.importWatchOnlyLabel,
          hint: context.loc.importWatchOnlyRequired,
          value: entity.label,
          onChanged: cubit.updateLabel,
          maxLines: 1,
        ),
        const _SyncBackendAndBirthdaySection(),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
        ),
        const Gap(24),
      ],
    );
  }
}

class _XpubDetailsWidget extends StatelessWidget {
  const _XpubDetailsWidget();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final watchOnlyWallet = context
        .watch<ImportWatchOnlyCubit>()
        .state
        .watchOnlyWallet;
    final entity = watchOnlyWallet! as WatchOnlyXpubEntity;
    final isXpub = entity.pubkey.startsWith('xpub');

    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          context.loc.importWatchOnlyExtendedPublicKey,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBText(entity.pubkey, style: context.font.bodyMedium),
        const Gap(24),
        if (!isXpub) ...[
          BBText(
            context.loc.importWatchOnlyXpubLabel,
            style: context.font.titleMedium,
          ),
          const Gap(8),
          BBText(
            entity.watchOnlyXpub.extendedPubkey.xpub,
            style: context.font.bodyMedium,
          ),
          const Gap(24),
        ],
        BBText(
          context.loc.importWatchOnlyType,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        if (!isXpub) ...[
          BBText(
            entity.extendedPubkey.derivation.label,
            style: context.font.bodyMedium,
          ),
          const Gap(24),
        ] else ...[
          InfoCard(
            title: context.loc.importWatchOnlyDisclaimerTitle,
            description: context.loc.importWatchOnlyDisclaimerDescription,
            bgColor: context.appColors.warning.withValues(alpha: 0.1),
            tagColor: context.appColors.warning,
          ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<satoshifier.Derivation>(
              alignment: Alignment.centerLeft,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 24.0),
              ),
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: context.appColors.text,
              ),
              initialValue: entity.extendedPubkey.derivation,
              items: [...satoshifier.Derivation.values]
                  .map(
                    (value) => DropdownMenuItem<satoshifier.Derivation>(
                      value: value,
                      child: BBText(
                        'BIP${value.purpose} - ${value.label}',
                        style: context.font.headlineSmall,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: cubit.onDerivationChanged,
            ),
          ),
          const Gap(24),
        ],
        BBText(
          context.loc.importWatchOnlyLabel,
          style: context.font.titleMedium,
        ),
        const Gap(8),
        BBInputText(
          onChanged: cubit.updateLabel,
          value: entity.label,
          maxLines: 1,
        ),
        const _SyncBackendAndBirthdaySection(),
        const Gap(24),
        BBButton.big(
          onPressed: cubit.import,
          label: context.loc.importWatchOnlyImport,
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
        ),
        const Gap(24),
      ],
    );
  }
}

/// Lets the user pick Electrum (today's unchanged behavior — no birthday, no
/// extra lookup) or compact block filters for the watch-only wallet about
/// to be imported. Only ever rendered when
/// [ImportWatchOnlyState.isCbfAvailable] is true (see that field's own doc
/// for the gate); shared by both the descriptor and xpub detail widgets
/// above.
class _SyncBackendAndBirthdaySection extends StatelessWidget {
  const _SyncBackendAndBirthdaySection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ImportWatchOnlyCubit>();
    final state = context.watch<ImportWatchOnlyCubit>().state;

    if (!state.isCbfAvailable) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: .start,
      children: [
        const Gap(24),
        BBText(
          context.loc.importWatchOnlySyncBackendTitle,
          style: context.font.titleMedium?.copyWith(fontWeight: .w600),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: _SelectableOption(
                label: context.loc.importWatchOnlySyncBackendElectrum,
                isSelected: state.syncBackend == BitcoinSyncBackend.electrum,
                onTap: () =>
                    cubit.selectSyncBackend(BitcoinSyncBackend.electrum),
              ),
            ),
            const Gap(12),
            Expanded(
              child: _SelectableOption(
                label:
                    context.loc.importWatchOnlySyncBackendCompactBlockFilters,
                isSelected:
                    state.syncBackend == BitcoinSyncBackend.compactBlockFilters,
                onTap: () => cubit.selectSyncBackend(
                  BitcoinSyncBackend.compactBlockFilters,
                ),
              ),
            ),
          ],
        ),
        if (state.syncBackend == BitcoinSyncBackend.compactBlockFilters) ...[
          const Gap(16),
          _BirthdayPicker(birthday: state.birthday, cubit: cubit),
        ],
        if (state.failure is BirthdayCheckpointFailure)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _BirthdayCheckpointFailureBanner(cubit: cubit),
          ),
      ],
    );
  }
}

class _SelectableOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectableOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border.all(
            color: isSelected
                ? context.appColors.primary
                : context.appColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: BBText(
          label,
          textAlign: .center,
          style: context.font.bodyMedium?.copyWith(
            color: context.appColors.text,
            fontWeight: isSelected ? .w600 : .w400,
          ),
        ),
      ),
    );
  }
}

/// Wallet birthday picker: "earliest possible" (this network's genesis
/// block, [birthday] `null`) is the default and needs no network lookup;
/// picking a specific date is resolved (in recovery mode, with a safety
/// margin) by the descriptor/xpub usecase right before the wallet is
/// imported.
class _BirthdayPicker extends StatelessWidget {
  final DateTime? birthday;
  final ImportWatchOnlyCubit cubit;

  const _BirthdayPicker({required this.birthday, required this.cubit});

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthday ?? now,
      firstDate: DateTime(2009),
      lastDate: now,
    );
    if (picked == null) return;
    cubit.updateBirthday(picked);
  }

  String _formatDate(BuildContext context, DateTime date) =>
      MaterialLocalizations.of(context).formatShortDate(date);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          context.loc.importWatchOnlyBirthdayTitle,
          style: context.font.titleMedium?.copyWith(fontWeight: .w600),
        ),
        const Gap(4),
        BBText(
          context.loc.importWatchOnlyBirthdayDescription,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: _SelectableOption(
                label: context.loc.importWatchOnlyBirthdayGenesisLabel,
                isSelected: birthday == null,
                onTap: () => cubit.updateBirthday(null),
              ),
            ),
            const Gap(12),
            Expanded(
              child: _SelectableOption(
                label: birthday == null
                    ? context.loc.importWatchOnlyBirthdayPickDate
                    : _formatDate(context, birthday!),
                isSelected: birthday != null,
                onTap: () => _pickDate(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Shown inline (in addition to the snackbar every other failure already
/// gets) when the descriptor/xpub usecase couldn't resolve the requested
/// birthday to a checkpoint — offers both recovery paths: retrying the same
/// date, or falling back to the earliest possible one (genesis), which
/// never requires a network lookup.
class _BirthdayCheckpointFailureBanner extends StatelessWidget {
  final ImportWatchOnlyCubit cubit;

  const _BirthdayCheckpointFailureBanner({required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: context.appColors.warning),
      ),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          BBText(
            context.loc.importWatchOnlyErrorBirthdayCheckpoint,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.text,
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: BBButton.small(
                  label: context.loc.importWatchOnlyBirthdayRetry,
                  onPressed: cubit.import,
                  bgColor: context.appColors.transparent,
                  textColor: context.appColors.onSurface,
                  outlined: true,
                  borderColor: context.appColors.border,
                ),
              ),
              const Gap(12),
              Expanded(
                child: BBButton.small(
                  label: context.loc.importWatchOnlyBirthdayUseGenesis,
                  onPressed: cubit.retryImportWithGenesisBirthday,
                  bgColor: context.appColors.primary,
                  textColor: context.appColors.onPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
