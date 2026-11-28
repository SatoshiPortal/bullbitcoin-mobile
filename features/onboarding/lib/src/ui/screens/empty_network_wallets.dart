import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';
import 'package:provisioning/provisioning.dart';

import '../../onboarding_l10n.dart';
import '../../presentation/network_wallet_setup_cubit.dart';
import '../../presentation/network_wallet_setup_failure_l10n.dart';

/// The route supplies navigation; this view only presents setup state/actions.
class EmptyNetworkWallets extends StatelessWidget {
  final NetworkWalletProvisioning Function() provisioning;
  final Stream<bool> refreshing;
  final bool initiallyRefreshing;
  final VoidCallback onMainnet;
  final VoidCallback onImport;
  final VoidCallback onRecoverEncryptedVault;
  final VoidCallback onReady;

  const EmptyNetworkWallets({
    super.key,
    required this.provisioning,
    required this.refreshing,
    required this.initiallyRefreshing,
    required this.onMainnet,
    required this.onImport,
    required this.onRecoverEncryptedVault,
    required this.onReady,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => NetworkWalletSetupCubit(provisioning())
      ..reloadAfterRefresh(refreshing, initiallyRefreshing: initiallyRefreshing)
      ..load(),
    child: BlocConsumer<NetworkWalletSetupCubit, NetworkWalletSetupState>(
      listener: (context, state) {
        if (state.options?.network == NetworkEnv.mainnet) {
          onMainnet();
        } else if (state.completed) {
          onReady();
        }
      },
      builder: (context, state) {
        final options = state.options;
        // Mainnet retains its existing onboarding destination without
        // exposing the developer-only setup choices during the lookup.
        if (options?.network == NetworkEnv.mainnet ||
            (options == null && state.failure == null)) {
          return const SizedBox.shrink();
        }
        final cubit = context.read<NetworkWalletSetupCubit>();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(BullSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BullFadingLinearProgress(trigger: state.working),
              const Gap(BullSpacing.lg),
              BullText(
                context.loc.networkWalletSetupTitle,
                style: context.bullType.title,
              ),
              if (options != null) ...[
                const Gap(BullSpacing.sm),
                BullText(switch (options.network) {
                  NetworkEnv.mainnet => context.loc.electrumMainnet,
                  NetworkEnv.testnet => context.loc.electrumTestnet,
                  NetworkEnv.regtest => context.loc.electrumRegtest,
                  NetworkEnv.signet => context.loc.networkFeatureUnavailable,
                }, style: context.bullType.body),
                if (!NetworkCapabilities.supports(switch (options.network) {
                  NetworkEnv.mainnet => LiquidNetwork.mainnet,
                  NetworkEnv.testnet => LiquidNetwork.testnet,
                  NetworkEnv.regtest => LiquidNetwork.regtest,
                  NetworkEnv.signet => BitcoinNetwork.signet,
                }, NetworkCapability.softwareWallet)) ...[
                  const Gap(BullSpacing.sm),
                  BullText(
                    '${context.loc.receiveLiquid}: ${context.loc.networkFeatureUnavailable}',
                    style: context.bullType.body,
                  ),
                ],
                const Gap(BullSpacing.lg),
                if (options.reusable.isNotEmpty) ...[
                  BullText(
                    context.loc.networkWalletReuseSecret,
                    style: context.bullType.body,
                  ),
                  const Gap(BullSpacing.sm),
                  for (final fingerprint in options.reusable) ...[
                    BullButton.secondary(
                      label:
                          '${context.loc.walletDetailsWalletFingerprintLabel}: ${fingerprint.hex}',
                      onPressed: (state.working)
                          ? null
                          : () => cubit.create(reuse: fingerprint),
                    ),
                    const Gap(BullSpacing.sm),
                  ],
                ],
                BullButton.secondary(
                  label: context.loc.importWalletImportMnemonic,
                  onPressed: (state.working) ? null : onImport,
                ),
                if (options.network == NetworkEnv.regtest) ...[
                  const Gap(BullSpacing.sm),
                  BullButton.secondary(
                    label: context.loc.onboardingEncryptedVault,
                    onPressed: (state.working) ? null : onRecoverEncryptedVault,
                  ),
                ],
                const Gap(BullSpacing.sm),
                BullButton.primary(
                  label: context.loc.onboardingCreateWalletButtonLabel,
                  onPressed: (state.working) ? null : () => cubit.create(),
                ),
              ],
              if (state.failure case final failure?) ...[
                const Gap(BullSpacing.md),
                BullText(
                  failure.toTranslated(context),
                  style: context.bullType.body,
                ),
                if (options == null)
                  BullButton.primary(
                    label: context.loc.retry,
                    onPressed: cubit.load,
                  ),
              ],
            ],
          ),
        );
      },
    ),
  );
}
