import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/loading_line_content.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/cubit.dart';
import 'package:bb_mobile/features/import_mnemonic/presentation/state.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
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
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: BBText(
                  state.error!.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ImportMnemonicCubit>();
          final scriptType = state.scriptType;

          if (!state.hasCheckedWallets && state.mnemonic != null) {
            cubit.checkWalletsStatusDirty();
          }

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
                  color:
                      isSelected
                          ? context.appColors.primary
                          : context.appColors.border,
                  width: 2,
                ),
                color:
                    isSelected
                        ? context.appColors.primary
                        : context.appColors.transparent,
              ),
              child:
                  isSelected
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
