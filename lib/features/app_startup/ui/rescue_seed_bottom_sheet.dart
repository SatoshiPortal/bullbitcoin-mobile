import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/rescue_seeds_cubit.dart';
import 'package:bb_mobile/features/app_startup/presentation/bloc/rescue_seeds_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class RescueSeedBottomSheet extends StatelessWidget {
  const RescueSeedBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RescueSeedsCubit, RescueSeedsState>(
      builder: (context, state) {
        return Container(
          color: context.appColors.background,
          child: Column(
            children: [
              if (state.isLoading)
                FadingLinearProgress(
                  height: 3,
                  trigger: state.isLoading,
                  backgroundColor: context.appColors.surface,
                  foregroundColor: context.appColors.primary,
                )
              else
                const SizedBox(height: 3),
              if (!state.isLoading && state.error != null)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: BBText(
                    context.loc.rescueSeedsFailedToLoad(state.error!),
                    style: context.font.bodyMedium,
                    color: context.appColors.error,
                    textAlign: TextAlign.center,
                  ),
                )
              else if (!state.isLoading && state.seeds.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: BBText(
                    context.loc.rescueSeedsNoSeedsFound,
                    style: context.font.bodyMedium,
                    color: context.appColors.onSurface.withValues(alpha: 0.7),
                    textAlign: TextAlign.center,
                  ),
                )
              else if (!state.isLoading && !state.seedsVisible)
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.visibility_off,
                            size: 64,
                            color: context.appColors.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                          const SizedBox(height: 16),
                          BBText(
                            context.loc.rescueSeedsFoundSeeds(
                              state.seeds.length,
                            ),
                            style: context.font.bodyLarge,
                            color: context.appColors.onSurface,
                          ),
                          const SizedBox(height: 8),
                          BBText(
                            context.loc.rescueSeedsMakeSureNoOneSees,
                            style: context.font.bodySmall,
                            color: context.appColors.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              context.read<RescueSeedsCubit>().showSeeds();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: context.appColors.primary,
                              foregroundColor: context.appColors.onPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                            ),
                            child: Text(context.loc.rescueSeedsShowButton),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24.0),
                    itemCount: state.seeds.length,
                    itemBuilder: (context, index) {
                      final seed = state.seeds[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: _buildSeedCard(context, seed, index + 1),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeedCard(BuildContext context, MnemonicSeed seed, int number) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.appColors.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BBText(
            context.loc.rescueSeedNumber(number),
            style: context.font.titleMedium?.copyWith(
              color: context.appColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          BBText(
            context.loc.rescueSeedFingerprint(seed.masterFingerprint),
            style: context.font.bodySmall,
            color: context.appColors.onSurface.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              seed.mnemonicWords.join(' '),
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
          if (seed.passphrase != null && seed.passphrase!.isNotEmpty) ...[
            const SizedBox(height: 12),
            BBText(
              context.loc.rescueSeedPassphrase,
              style: context.font.bodySmall?.copyWith(
                color: context.appColors.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                seed.passphrase!,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.error,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
