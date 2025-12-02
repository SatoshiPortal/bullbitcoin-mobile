import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AllSeedViewScreen extends StatefulWidget {
  const AllSeedViewScreen({super.key});

  @override
  State<AllSeedViewScreen> createState() => _AllSeedViewScreenState();
}

class _AllSeedViewScreenState extends State<AllSeedViewScreen>
    with PrivacyScreen {
  bool _hasStartedFetch = false;
  AllSeedViewCubit? _cubit;

  @override
  void initState() {
    super.initState();
    enableScreenPrivacy();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<AllSeedViewCubit>();
    // Fetch seeds after the first frame is rendered to avoid blocking navigation
    if (!_hasStartedFetch) {
      _hasStartedFetch = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _cubit?.fetchAllSeeds();
        }
      });
    }
  }

  @override
  void dispose() {
    // Clear state when navigating away
    _cubit?.clearState();
    _cubit?.hideSeeds();
    disableScreenPrivacy();
    super.dispose();
  }

  Future<void> _showWarningDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: context.colour.onPrimary,
          title: Text(
            'Security Warning',
            style: context.font.headlineSmall?.copyWith(
              color: context.colour.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              'Displaying seed phrases is a security risk. Anyone who sees your seed phrase can access your funds. Make sure you are in a private location and that no one can see your screen.',
              style: context.font.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: context.font.bodyMedium),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AllSeedViewCubit>().showSeeds();
              },
              child: Text(
                'I Understand',
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
            'WARNING!',
            style: context.font.headlineSmall?.copyWith(
              color: context.colour.error,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Text(
              'Deleting the seed is an irreversible action. Only do this if you have secure backups of this seed or the associated wallets have been fully drained.',
              style: context.font.bodyMedium,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('Cancel', style: context.font.bodyMedium),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.read<AllSeedViewCubit>().deleteSeed(
                  seed.masterFingerprint,
                );
              },
              child: Text(
                'Delete',
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          context.read<AllSeedViewCubit>().hideSeeds();
          context.read<AllSeedViewCubit>().clearState();
        }
      },
      child: BlocBuilder<AllSeedViewCubit, AllSeedViewState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const BBText(
                'Seed Viewer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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
                        'This may take a while to load if you have a lot of seeds on this device.',
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
                      'No seeds found.',
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
                            label: 'Show Seeds',
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
                        'Existing Wallets (${state.existingWallets.length})',
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
                        'Old Wallets (${state.oldWallets.length})',
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
                  BBText('Passphrase:', style: context.font.bodyLarge),
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
