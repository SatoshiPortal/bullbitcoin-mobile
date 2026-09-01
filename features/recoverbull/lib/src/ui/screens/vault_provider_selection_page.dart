import '../../presentation/bloc.dart';
import '../../presentation/recoverbull_failure_l10n.dart';
import './vault_created_page.dart';
import './vault_selected_page.dart';
import '../widgets/key_server_status_widget.dart';
import '../../router/flow_type.dart';
import 'package:flutter/material.dart';
import '../../l10n/context_localizations.dart';
import '../support.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:go_router/go_router.dart';

class VaultProviderSelectionPage extends StatelessWidget {
  const VaultProviderSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            final bloc = context.read<RecoverBullBloc>();
            if (bloc.hasPendingProviderSave) {
              SnackBarUtils.showSnackBar(
                context,
                context.loc.recoverbullProviderSaveFailed,
              );
              return;
            }
            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              context.pop();
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(context.loc.recoverbullSelectVaultProvider),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 20),
            child: KeyServerStatusWidget(),
          ),
        ],
      ),
      body: BlocConsumer<RecoverBullBloc, RecoverBullState>(
        listenWhen: (previous, current) =>
            current.failure != null && previous.failure != current.failure ||
            current.vault != null && previous.vault == null,
        listener: (context, state) {
          if (state.failure != null) {
            SnackBarUtils.showSnackBar(
              context,
              state.failure!.toTranslated(context),
            );
            return;
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
                    builder: (context) => VaultSelectedPage(
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
                backgroundColor: context.appColors.surface,
                foregroundColor: context.appColors.primary,
                height: 2.0,
              ),

              if (state.flow == RecoverBullFlow.secureVault && state.isLoading)
                Expanded(
                  child: Center(
                    child: ProgressScreen(
                      isLoading: true,
                      title: context.loc.recoverbullCreatingVault,
                      description: context.loc.recoverbullConnectingTor,
                    ),
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
                          BlurredBottomSheet.show(
                            context: context,
                            child: const HowToDecideVaultLocation(),
                          );
                        },
                        child: BBText(
                          context.loc.backupWalletHowToDecide,
                          style: context.font.headlineLarge?.copyWith(
                            color: context.appColors.primary,
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
          color: context.appColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: .min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: .spaceBetween,
                children: [
                  const Spacer(),
                  BBText(
                    context.loc.backupWalletHowToDecideBackupModalTitle,
                    style: context.font.headlineMedium,
                    textAlign: .center,
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Icon(
                      Icons.close,
                      color: context.appColors.onSurface,
                    ),
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
                    crossAxisAlignment: .start,
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
                              text: context
                                  .loc
                                  .backupWalletHowToDecideVaultCustomRecommendation,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: .bold,
                              ),
                            ),
                            TextSpan(
                              text: context
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
                              text: context
                                  .loc
                                  .backupWalletHowToDecideVaultCloudRecommendation,
                              style: context.font.labelMedium?.copyWith(
                                fontWeight: .bold,
                              ),
                            ),
                            TextSpan(
                              text: context
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
