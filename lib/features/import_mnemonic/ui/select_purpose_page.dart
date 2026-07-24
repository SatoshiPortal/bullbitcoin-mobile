import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/import_mnemonic_failure_l10n.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SelectScriptTypePage extends StatelessWidget {
  const SelectScriptTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.importMnemonicSelectScriptType,
          color: context.appColors.background,
          onBack: () => context.goNamed(WalletRoute.walletHome.name),
        ),
      ),
      body: BlocConsumer<ImportMnemonicCubit, ImportMnemonicState>(
        listener: (context, state) {
          if (state.failure != null) {
            SnackBarUtils.showSnackBar(
              context,
              state.failure!.toTranslated(context),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ImportMnemonicCubit>();
          final scriptType = state.scriptType;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: .spaceEvenly,
                children: [
                  BBText(
                    context.loc.importMnemonicSyncMessage,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                    textAlign: .center,
                  ),
                  const Gap(24),
                  Column(
                    children: [
                      _WalletTypeCard(
                        title: context.loc.importMnemonicSegwit,
                        status: state.bip84Status,
                        isSelected: scriptType == ScriptType.bip84,
                        onTap: () => cubit.updateBip39Purpose(ScriptType.bip84),
                      ),
                      const Gap(16),
                      _WalletTypeCard(
                        title: context.loc.importMnemonicNestedSegwit,
                        status: state.bip49Status,
                        isSelected: scriptType == ScriptType.bip49,
                        onTap: () => cubit.updateBip39Purpose(ScriptType.bip49),
                      ),
                      const Gap(16),
                      _WalletTypeCard(
                        title: context.loc.importMnemonicLegacy,
                        status: state.bip44Status,
                        isSelected: scriptType == ScriptType.bip44,
                        onTap: () => cubit.updateBip39Purpose(ScriptType.bip44),
                      ),
                    ],
                  ),
                  if (state.isCbfAvailable) ...[
                    const Gap(24),
                    _SyncBackendSection(state: state, cubit: cubit),
                  ],
                  if (state.failure is ImportMnemonicBirthdayCheckpointFailure)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _BirthdayCheckpointFailureBanner(cubit: cubit),
                    ),
                  const Gap(16),

                  BBButton.big(
                    label: context.loc.importMnemonicContinue,
                    onPressed: cubit.import,
                    bgColor: context.appColors.onSurface,
                    textColor: context.appColors.surface,
                    disabled: state.isLoading,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WalletTypeCard extends StatelessWidget {
  final String title;
  final ({BigInt satoshis, int transactions})? status;
  final bool isSelected;
  final VoidCallback onTap;

  const _WalletTypeCard({
    required this.title,
    required this.status,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          border: Border.all(color: context.appColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: context.appColors.border,
              offset: isSelected ? const Offset(0, 6) : const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BBText(
                    title,
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: .w600,
                      color: context.appColors.text,
                    ),
                  ),

                  if (status != null) ...[
                    const Gap(8),
                    BBText(
                      context.loc.importMnemonicBalanceLabel(
                        status!.satoshis.toString(),
                      ),
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                    const Gap(4),
                    BBText(
                      context.loc.importMnemonicTransactionsLabel(
                        status!.transactions.toString(),
                      ),
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.textMuted,
                      ),
                    ),
                  ],
                  if (status == null) ...[
                    const Gap(8),
                    const LoadingLineContent(
                      height: 8,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: .circle,
                border: Border.all(
                  color: isSelected
                      ? context.appColors.primary
                      : context.appColors.border,
                  width: 2,
                ),
                color: isSelected
                    ? context.appColors.primary
                    : context.appColors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.circle,
                      size: 12,
                      color: context.appColors.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user pick Electrum (today's unchanged behavior — no birthday, no
/// extra lookup) or compact block filters for the wallet about to be
/// imported. Only ever shown when [ImportMnemonicState.isCbfAvailable] is
/// true (see that field's own doc for the gate) — the caller
/// (`SelectScriptTypePage`) is responsible for that check.
class _SyncBackendSection extends StatelessWidget {
  final ImportMnemonicState state;
  final ImportMnemonicCubit cubit;

  const _SyncBackendSection({required this.state, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      children: [
        BBText(
          context.loc.importMnemonicSyncBackendTitle,
          style: context.font.titleMedium?.copyWith(fontWeight: .w600),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: _SyncBackendOption(
                label: context.loc.importMnemonicSyncBackendElectrum,
                isSelected: state.syncBackend == BitcoinSyncBackend.electrum,
                onTap: () =>
                    cubit.selectSyncBackend(BitcoinSyncBackend.electrum),
              ),
            ),
            const Gap(12),
            Expanded(
              child: _SyncBackendOption(
                label: context.loc.importMnemonicSyncBackendCompactBlockFilters,
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
      ],
    );
  }
}

class _SyncBackendOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SyncBackendOption({
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
/// margin) by `ImportWalletUsecase.execute` right before the wallet is
/// created — see that usecase's own doc for why a `null` birthday can never
/// fail here while a specific date can.
class _BirthdayPicker extends StatelessWidget {
  final DateTime? birthday;
  final ImportMnemonicCubit cubit;

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
          context.loc.importMnemonicBirthdayTitle,
          style: context.font.titleMedium?.copyWith(fontWeight: .w600),
        ),
        const Gap(4),
        BBText(
          context.loc.importMnemonicBirthdayDescription,
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        Row(
          children: [
            Expanded(
              child: _SyncBackendOption(
                label: context.loc.importMnemonicBirthdayGenesisLabel,
                isSelected: birthday == null,
                onTap: () => cubit.updateBirthday(null),
              ),
            ),
            const Gap(12),
            Expanded(
              child: _SyncBackendOption(
                label: birthday == null
                    ? context.loc.importMnemonicBirthdayPickDate
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
/// gets) when `ImportWalletUsecase.execute` couldn't resolve the requested
/// birthday to a checkpoint — offers both recovery paths: retrying the same
/// date, or falling back to the earliest possible one (genesis), which
/// never requires a network lookup.
class _BirthdayCheckpointFailureBanner extends StatelessWidget {
  final ImportMnemonicCubit cubit;

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
            context.loc.importMnemonicBirthdayCheckpointError,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.text,
            ),
          ),
          const Gap(12),
          Row(
            children: [
              Expanded(
                child: BBButton.small(
                  label: context.loc.importMnemonicBirthdayRetry,
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
                  label: context.loc.importMnemonicBirthdayUseGenesis,
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
