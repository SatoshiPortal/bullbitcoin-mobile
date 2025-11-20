import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/loading/progress_screen.dart';
import 'package:bb_mobile/core/widgets/selectors/recoverbull_vault_provider_selector.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_created_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/vault_selected_page.dart';
import 'package:bb_mobile/features/recoverbull/ui/widgets/key_server_status_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class VaultProviderSelectionPage extends StatelessWidget {
  const VaultProviderSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.recoverbullSelectVaultProvider),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: KeyServerStatusWidget(),
          ),
        ],
      ),
      body: BlocConsumer<RecoverBullBloc, RecoverBullState>(
        listenWhen:
            (previous, current) =>
                previous.error != current.error ||
                current.vault != null && previous.vault != current.vault,
        listener: (context, state) {
          if (state.error != null) {
            SnackBarUtils.showSnackBar(
              context,
              state.error!.toTranslated(context),
            );
            context.read<RecoverBullBloc>().add(const OnClearError());
          }

          if (state.vault != null && state.vaultProvider != null) {
            switch (state.flow) {
              case RecoverBullFlow.secureVault:
                SnackBarUtils.showSnackBar(
                  context,
                  context.loc.recoverbullVaultCreatedSuccess,
                );
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const VaultCreatedPage(),
                  ),
                );
              default:
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (context) => VaultSelectedPage(
                          provider: state.vaultProvider!,
                          vault: state.vault!,
                          flow: state.flow,
                        ),
                  ),
                );
            }
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              FadingLinearProgress(
                trigger: state.isLoading,
                backgroundColor: context.colour.surface,
                foregroundColor: context.colour.primary,
                height: 2.0,
              ),

              if (state.flow == RecoverBullFlow.secureVault && state.isLoading)
                Center(
                  child: ProgressScreen(
                    isLoading: true,
                    title: context.loc.recoverbullCreatingVault,
                    description: context.loc.recoverbullConnectingTor,
                  ),
                ),

              if (!state.isLoading) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: RecoverbullVaultProviderSelector(
                    onProviderSelected: (provider) {
                      context.read<RecoverBullBloc>().add(
                        OnVaultProviderSelection(provider: provider),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const HowToDecideVaultLocation(),
                          );
                        },
                        child: BBText(
                          context.loc.backupWalletHowToDecide,
                          style: context.font.headlineLarge?.copyWith(
                            color: context.colour.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class HowToDecideVaultLocation extends StatelessWidget {
  const HowToDecideVaultLocation({super.key});

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: context.colour.onPrimary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Spacer(),
                  BBText(
                    context.loc.backupWalletHowToDecideBackupModalTitle,
                    style: context.font.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(Icons.close, color: context.colour.secondary),
                  ),
                ],
              ),
            ),
            const Gap(32),
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BBText(
                        context.loc.backupWalletHowToDecideVaultCloudSecurity,
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                        maxLines: 16,
                      ),
                      const Gap(32),
                      BBText(
                        context.loc.backupWalletHowToDecideVaultCustomLocation,
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                        maxLines: 16,
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.font.bodyMedium,
                          children: [
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideVaultCustomRecommendation,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideVaultCustomRecommendationText,
                              style: context.font.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      RichText(
                        text: TextSpan(
                          style: context.font.bodyMedium,
                          children: [
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideVaultCloudRecommendation,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text:
                                  context
                                      .loc
                                      .backupWalletHowToDecideVaultCloudRecommendationText,
                              style: context.font.labelMedium,
                            ),
                          ],
                        ),
                      ),
                      const Gap(12),
                      BBText(
                        context.loc.backupWalletHowToDecideVaultMoreInfo,
                        style: context.font.labelMedium?.copyWith(
                          height: 1.5,
                          fontSize: 14,
                        ),
                      ),

                      const Gap(20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
