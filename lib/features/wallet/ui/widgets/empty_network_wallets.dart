import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_failure_l10n.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/presentation/network_wallet_setup_cubit.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:primitives/primitives.dart';

/// The route supplies navigation; this view only presents setup state/actions.
class EmptyNetworkWallets extends StatelessWidget {
  final NetworkWalletSetupCubit Function() createSetupCubit;
  final VoidCallback onMainnet;
  final VoidCallback onImport;
  final VoidCallback onRecoverEncryptedVault;

  const EmptyNetworkWallets({
    super.key,
    required this.createSetupCubit,
    required this.onMainnet,
    required this.onImport,
    required this.onRecoverEncryptedVault,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => createSetupCubit()..load(),
    child: BlocListener<WalletBloc, WalletState>(
      listenWhen: (previous, current) =>
          previous.isRefreshing && !current.isRefreshing,
      listener: (context, state) =>
          context.read<NetworkWalletSetupCubit>().load(),
      child: BlocConsumer<NetworkWalletSetupCubit, NetworkWalletSetupState>(
        listener: (context, state) {
          if (state.options?.network == NetworkEnv.mainnet) {
            onMainnet();
          } else if (state.completed) {
            context.read<WalletBloc>().add(const WalletStarted());
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
                      BullButton.big(
                        label:
                            '${context.loc.walletDetailsWalletFingerprintLabel}: ${fingerprint.hex}',
                        onPressed: () => cubit.create(reuse: fingerprint),
                        disabled: state.working,
                        bgColor: context.bull.surface,
                        textColor: context.bull.onSurface,
                        outlined: true,
                      ),
                      const Gap(BullSpacing.sm),
                    ],
                  ],
                  BullButton.big(
                    label: context.loc.importWalletImportMnemonic,
                    onPressed: onImport,
                    disabled: state.working,
                    bgColor: context.bull.surface,
                    textColor: context.bull.onSurface,
                    outlined: true,
                  ),
                  if (options.network == NetworkEnv.regtest) ...[
                    const Gap(BullSpacing.sm),
                    BullButton.big(
                      label: context.loc.onboardingEncryptedVault,
                      onPressed: onRecoverEncryptedVault,
                      disabled: state.working,
                      bgColor: context.bull.surface,
                      textColor: context.bull.onSurface,
                      outlined: true,
                    ),
                  ],
                  const Gap(BullSpacing.sm),
                  BullButton.big(
                    label: context.loc.onboardingCreateWalletButtonLabel,
                    onPressed: () => cubit.create(),
                    disabled: state.working,
                    bgColor: context.bull.primary,
                    textColor: context.bull.onPrimary,
                  ),
                ],
                if (state.failure case final failure?) ...[
                  const Gap(BullSpacing.md),
                  BullText(
                    failure.toTranslated(context),
                    style: context.bullType.body,
                  ),
                  if (options == null)
                    BullButton.big(
                      label: context.loc.retry,
                      onPressed: cubit.load,
                      bgColor: context.bull.primary,
                      textColor: context.bull.onPrimary,
                    ),
                ],
              ],
            ),
          );
        },
      ),
    ),
  );
}
