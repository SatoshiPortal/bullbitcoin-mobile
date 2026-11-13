import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/import_mnemonic_failure_l10n.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullShimmerLine, BullSnackBar, BullText, BullTopBar, Gap;
import 'package:go_router/go_router.dart';

class SelectScriptTypePage extends StatelessWidget {
  const SelectScriptTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.importMnemonicSelectScriptType,
          color: context.appColors.background,
          onBack: () => context.goNamed(WalletRoute.walletHome.name),
        ),
      ),
      body: BlocConsumer<ImportMnemonicCubit, ImportMnemonicState>(
        listener: (context, state) {
          if (state.failure != null) {
            BullSnackBar.show(
              context,
              message: state.failure!.toTranslated(context),
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
                  BullText(
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
                        scan: state.bip84Scan,
                        isSelected: scriptType == ScriptType.bip84,
                        onTap: () => cubit.updateBip39Purpose(ScriptType.bip84),
                        onRetry: () => cubit.retryScan(ScriptType.bip84),
                      ),
                      const Gap(16),
                      _WalletTypeCard(
                        title: context.loc.importMnemonicNestedSegwit,
                        scan: state.bip49Scan,
                        isSelected: scriptType == ScriptType.bip49,
                        onTap: () => cubit.updateBip39Purpose(ScriptType.bip49),
                        onRetry: () => cubit.retryScan(ScriptType.bip49),
                      ),
                      const Gap(16),
                      _WalletTypeCard(
                        title: context.loc.importMnemonicLegacy,
                        scan: state.bip44Scan,
                        isSelected: scriptType == ScriptType.bip44,
                        onTap: () => cubit.updateBip39Purpose(ScriptType.bip44),
                        onRetry: () => cubit.retryScan(ScriptType.bip44),
                      ),
                    ],
                  ),
                  const Gap(16),

                  BullButton.big(
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
  final ScriptTypeScan scan;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRetry;

  const _WalletTypeCard({
    required this.title,
    required this.scan,
    required this.isSelected,
    required this.onTap,
    required this.onRetry,
  });

  List<Widget> _summary(BuildContext context, BigInt satoshis, int count) => [
    BullText(
      context.loc.importMnemonicBalanceLabel(satoshis.toString()),
      style: _mutedStyle(context),
    ),
    const Gap(4),
    BullText(
      context.loc.importMnemonicTransactionsLabel(count.toString()),
      style: _mutedStyle(context),
    ),
  ];

  TextStyle? _mutedStyle(BuildContext context) =>
      context.font.bodyMedium?.copyWith(color: context.appColors.textMuted);

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
                  BullText(
                    title,
                    style: context.font.titleMedium?.copyWith(
                      fontWeight: .w600,
                      color: context.appColors.text,
                    ),
                  ),
                  const Gap(8),
                  ...switch (scan) {
                    ScriptTypeScanLoading() => const [
                      BullShimmerLine(height: 8, padding: EdgeInsets.zero),
                    ],
                    ScriptTypeScanFound(:final satoshis, :final transactions) =>
                      _summary(context, satoshis, transactions),
                    ScriptTypeScanEmpty() => _summary(context, BigInt.zero, 0),
                    ScriptTypeScanFailed(:final failure) => [
                      BullText(
                        failure.toTranslated(context),
                        style: _mutedStyle(context),
                      ),
                      const Gap(8),
                      BullButton.small(
                        label: context.loc.retry,
                        onPressed: onRetry,
                        iconData: Icons.refresh,
                        iconFirst: true,
                        outlined: true,
                        compact: true,
                        bgColor: context.appColors.transparent,
                        borderColor: context.appColors.border,
                        textColor: context.appColors.text,
                      ),
                    ],
                  },
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
