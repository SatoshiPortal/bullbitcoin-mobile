import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
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
          cubit.state.error == null) {
        cubit.fetchAllSeeds();
      }
    });
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          disableScreenPrivacy();
        }
      },
      child: BlocBuilder<AllSeedViewCubit, AllSeedViewState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: BBText(
                context.loc.allSeedViewTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child:
                    state.loading
                        ? FadingLinearProgress(
                          height: 3,
                          trigger: state.loading,
                          backgroundColor: context.colour.surface,
                          foregroundColor: context.colour.primary,
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
                        color: context.colour.onSurface.withValues(alpha: 0.7),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (state.error != null) {
                  return Center(
                    child: BBText(state.error!, style: context.font.bodyLarge),
                  );
                }
                if (state.allSeeds.isEmpty) {
                  return Center(
                    child: BBText(
                      context.loc.allSeedViewNoSeedsFound,
                      style: context.font.bodyLarge,
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
                              color: context.colour.onSurface.withValues(
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
                            bgColor: context.colour.secondary,
                            textColor: context.colour.onSecondary,
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
                          fontWeight: FontWeight.bold,
                        ),
                        color: context.colour.onSurface,
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
                          fontWeight: FontWeight.bold,
                        ),
                        color: context.colour.onSurface,
                      ),
                      const SizedBox(height: 8),
                      ...state.oldWallets.map<Widget>(
                        (seed) =>
                            _buildSeedCard(context, seed, isOldWallet: true),
                      ),
                    ],
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWarningDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.colour.onPrimary,
          title: Text(
            context.loc.allSeedViewSecurityWarningTitle,
            style: context.font.headlineSmall?.copyWith(
              color: context.colour.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              context.loc.allSeedViewSecurityWarningMessage,
              style: context.font.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.loc.cancel, style: context.font.bodyMedium),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AllSeedViewCubit>().showSeeds();
              },
              child: Text(
                context.loc.allSeedViewIUnderstandButton,
                style: context.font.bodyMedium?.copyWith(
                  color: context.colour.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteWarningDialog(
    BuildContext context,
    MnemonicSeed seed,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.colour.onPrimary,
          title: Text(
            context.loc.allSeedViewDeleteWarningTitle,
            style: context.font.headlineSmall?.copyWith(
              color: context.colour.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              context.loc.allSeedViewDeleteWarningMessage,
              style: context.font.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(context.loc.cancel, style: context.font.bodyMedium),
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
                  color: context.colour.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colour.onPrimary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.colour.primary, width: 2),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: BBText(
                    seed.mnemonicWords.join(' '),
                    style: context.font.bodyMedium,
                    color: context.colour.secondary,
                    maxLines: 5,
                  ),
                ),
                if (isOldWallet) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: context.colour.error,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BBText(
                    context.loc.allSeedViewPassphraseLabel,
                    style: context.font.bodyLarge,
                  ),
                  BBText(
                    seed.passphrase!,
                    style: context.font.bodyMedium,
                    color: context.colour.onSurface,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
