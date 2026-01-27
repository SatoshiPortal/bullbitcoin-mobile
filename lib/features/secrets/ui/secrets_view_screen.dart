import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/secrets/presentation/blocs/secrets_view_bloc.dart';
import 'package:bb_mobile/features/secrets/presentation/blocs/secrets_view_event.dart';
import 'package:bb_mobile/features/secrets/ui/secret_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SecretsViewScreen extends StatelessWidget with PrivacyScreen {
  const SecretsViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    enableScreenPrivacy();
    final bloc = context.read<SecretsViewBloc>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (bloc.state.isInitial) {
        bloc.add(const SecretsViewLoadRequested());
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          disableScreenPrivacy();
        }
      },
      child: BlocBuilder<SecretsViewBloc, SecretsViewState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: BBText(
                context.loc.allSeedViewTitle,
                style: const TextStyle(fontWeight: .bold, fontSize: 20),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: state.isLoading
                    ? FadingLinearProgress(
                        height: 3,
                        trigger: state.isLoading,
                        backgroundColor: context.appColors.surface,
                        foregroundColor: context.appColors.primary,
                      )
                    : const SizedBox(height: 3),
              ),
            ),
            body: Builder(
              builder: (context) {
                if (state.isLoading) {
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

                if (state.hasLoadError) {
                  return state.maybeWhen(
                    failedToLoad: (error) => Center(
                      child: BBText(
                        error.toString(),
                        style: context.font.bodyLarge,
                        color: context.appColors.error,
                      ),
                    ),
                    orElse: () => const SizedBox.shrink(),
                  );
                }

                final allSecrets = state.allSecrets;
                if (allSecrets.isEmpty) {
                  return Center(
                    child: BBText(
                      context.loc.allSeedViewNoSeedsFound,
                      style: context.font.bodyLarge,
                      color: context.appColors.onSurface,
                    ),
                  );
                }

                // Separate current and legacy secrets
                final currentSecrets = allSecrets
                    .where((secret) => !secret.isLegacy)
                    .toList();
                final legacySecrets = allSecrets
                    .where((secret) => secret.isLegacy)
                    .toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (currentSecrets.isNotEmpty) ...[
                      BBText(
                        context.loc.allSeedViewExistingWallets(
                          currentSecrets.length,
                        ),
                        style: context.font.headlineSmall?.copyWith(
                          fontWeight: .bold,
                        ),
                        color: context.appColors.onSurface,
                      ),
                      const SizedBox(height: 8),
                      ...currentSecrets.map<Widget>(
                        (secretViewModel) => SecretItemWidget(
                          key: ValueKey(secretViewModel.fingerprint),
                          secretViewModel: secretViewModel,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (legacySecrets.isNotEmpty) ...[
                      BBText(
                        context.loc.allSeedViewOldWallets(legacySecrets.length),
                        style: context.font.headlineSmall?.copyWith(
                          fontWeight: .bold,
                        ),
                        color: context.appColors.onSurface,
                      ),
                      const SizedBox(height: 8),
                      ...legacySecrets.map<Widget>(
                        (secretViewModel) => SecretItemWidget(
                          key: ValueKey(secretViewModel.fingerprint),
                          secretViewModel: secretViewModel,
                        ),
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
}
