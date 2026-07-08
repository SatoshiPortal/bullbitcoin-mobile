import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap_master_key_info.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/dialog/blurred_dialog.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_failure_l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AllSeedViewScreen extends StatelessWidget with PrivacyScreen {
  const AllSeedViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    enableScreenPrivacy();
    final cubit = context.read<AllSeedViewCubit>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (cubit.state.loading &&
          cubit.state.existingWallets.isEmpty &&
          cubit.state.oldWallets.isEmpty &&
          cubit.state.failure == null) {
        cubit.fetchAllSeeds();
      }
    });
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          disableScreenPrivacy();
        }
      },
      child: BlocListener<AllSeedViewCubit, AllSeedViewState>(
        listenWhen: (p, c) => p.failure != c.failure,
        listener: (context, state) {
          if (state.failure case final failure?
              when failure is! AllSeedViewFetchFailure) {
            SnackBarUtils.showSnackBar(context, failure.toTranslated(context));
          }
        },
        child: BlocBuilder<AllSeedViewCubit, AllSeedViewState>(
          builder: (context, state) {
            return Scaffold(
              appBar: AppBar(
                title: BBText(
                  context.loc.allSeedViewTitle,
                  style: const TextStyle(fontWeight: .bold, fontSize: 20),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: state.loading
                      ? FadingLinearProgress(
                          height: 3,
                          trigger: state.loading,
                          backgroundColor: context.appColors.surface,
                          foregroundColor: context.appColors.primary,
                        )
                      : const SizedBox(height: 3),
                ),
              ),
              body: Builder(
                builder: (context) {
                  if (state.loading) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: BBText(
                          context.loc.allSeedViewLoadingMessage,
                          style: context.font.bodyMedium,
                          color: context.appColors.onSurface.withValues(
                            alpha: 0.7,
                          ),
                          textAlign: .center,
                        ),
                      ),
                    );
                  }
                  if (state.failure is AllSeedViewFetchFailure) {
                    return Center(
                      child: BBText(
                        state.failure!.toTranslated(context),
                        style: context.font.bodyLarge,
                        color: context.appColors.error,
                      ),
                    );
                  }
                  if (state.allSeeds.isEmpty) {
                    return Center(
                      child: BBText(
                        context.loc.allSeedViewNoSeedsFound,
                        style: context.font.bodyLarge,
                        color: context.appColors.onSurface,
                      ),
                    );
                  }
                  if (!state.seedsVisible) {
                    return SafeArea(
                      child: Column(
                        children: [
                          Expanded(
                            child: Center(
                              child: Icon(
                                Icons.visibility_off,
                                size: 120,
                                color: context.appColors.onSurface.withValues(
                                  alpha: 0.3,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: BBButton.big(
                              label: context.loc.allSeedViewShowSeedsButton,
                              onPressed: () => _showWarningDialog(context),
                              bgColor: context.appColors.secondary,
                              textColor: context.appColors.onSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (state.existingWallets.isNotEmpty) ...[
                        BBText(
                          context.loc.allSeedViewExistingWallets(
                            state.existingWallets.length,
                          ),
                          style: context.font.headlineSmall?.copyWith(
                            fontWeight: .bold,
                          ),
                          color: context.appColors.onSurface,
                        ),
                        const SizedBox(height: 8),
                        ...state.existingWallets.map<Widget>(
                          (seed) =>
                              _buildSeedCard(context, seed, isOldWallet: false),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (state.oldWallets.isNotEmpty) ...[
                        BBText(
                          context.loc.allSeedViewOldWallets(
                            state.oldWallets.length,
                          ),
                          style: context.font.headlineSmall?.copyWith(
                            fontWeight: .bold,
                          ),
                          color: context.appColors.onSurface,
                        ),
                        const SizedBox(height: 8),
                        ...state.oldWallets.map<Widget>(
                          (seed) =>
                              _buildSeedCard(context, seed, isOldWallet: true),
                        ),
                      ],
                      if (state.swapMasterKey != null) ...[
                        const SizedBox(height: 24),
                        BBText(
                          'Swap mnemonic',
                          style: context.font.headlineSmall?.copyWith(
                            fontWeight: .bold,
                          ),
                          color: context.appColors.onSurface,
                        ),
                        const SizedBox(height: 8),
                        _buildSwapKeyCard(context, state.swapMasterKey!),
                      ],
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showWarningDialog(BuildContext context) {
    return BlurredDialog.show<void>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          context.loc.allSeedViewSecurityWarningTitle,
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            context.loc.allSeedViewSecurityWarningMessage,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AllSeedViewCubit>().showSeeds();
            },
            child: Text(
              context.loc.allSeedViewIUnderstandButton,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.primary,
                fontWeight: .bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteWarningDialog(
    BuildContext context,
    MnemonicSeed seed,
  ) {
    return BlurredDialog.show<void>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          context.loc.allSeedViewDeleteWarningTitle,
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.error,
            fontWeight: .bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            context.loc.allSeedViewDeleteWarningMessage,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AllSeedViewCubit>().deleteSeed(
                seed.masterFingerprint,
              );
            },
            child: Text(
              context.loc.delete,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
                fontWeight: .bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteSwapWarningDialog(BuildContext context) {
    return BlurredDialog.show<void>(
      context: context,
      isDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: context.appColors.surface,
        title: Text(
          'Delete swap mnemonic?',
          style: context.font.headlineSmall?.copyWith(
            color: context.appColors.error,
            fontWeight: .bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Text(
            'This removes the swap master key from secure storage. It will be '
            're-derived from your wallet seed the next time the app needs it, '
            'with the same fingerprint. Ongoing swaps are unaffected.',
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.onSurface,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              context.loc.cancel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<AllSeedViewCubit>().deleteSwapMnemonic();
            },
            child: Text(
              context.loc.delete,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.error,
                fontWeight: .bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapKeyCard(BuildContext context, SwapMasterKeyInfo swapKey) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.appColors.outline, width: 1),
        ),
        child: Column(
          crossAxisAlignment: .start,
          children: [
            Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: BBText(
                    swapKey.mnemonic,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                    maxLines: 5,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: context.appColors.error,
                  ),
                  onPressed: () => _showDeleteSwapWarningDialog(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            BBText(
              'Fingerprint: ${swapKey.fingerprint} (${swapKey.network})',
              style: context.font.bodyMedium,
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
            BBText(
              'Linked wallet: ${swapKey.walletFingerprint}',
              style: context.font.bodyMedium,
              color: context.appColors.onSurface.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeedCard(
    BuildContext context,
    MnemonicSeed seed, {
    required bool isOldWallet,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: .start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.appColors.outline, width: 1),
            ),
            child: Row(
              crossAxisAlignment: .start,
              children: [
                Expanded(
                  child: BBText(
                    seed.mnemonicWords.join(' '),
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                    maxLines: 5,
                  ),
                ),
                if (isOldWallet) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.appColors.error,
                    ),
                    onPressed: () => _showDeleteWarningDialog(context, seed),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ],
            ),
          ),
          if (seed.passphrase != null && seed.passphrase!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 8.0),
              child: Column(
                crossAxisAlignment: .start,
                children: [
                  BBText(
                    context.loc.allSeedViewPassphraseLabel,
                    style: context.font.bodyLarge?.copyWith(
                      color: context.appColors.onSurface,
                    ),
                  ),
                  BBText(
                    seed.passphrase!,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
