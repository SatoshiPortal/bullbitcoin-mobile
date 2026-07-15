import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_notification.dart';
import 'package:bb_mobile/features/sp/presentation/sp_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpHeaderValidationScreen extends StatelessWidget {
  const SpHeaderValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpCubit>().state;
    final failed =
        state.headerValidationStatus == SpHeaderValidationStatus.failed;
    final progress = _progressValue(state);
    final percent = (progress * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.loc.spHeaderValidationTitle,
          style: context.font.headlineMedium,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: failed
                  ? context.appColors.errorContainer
                  : context.appColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_title(context, state), style: context.font.titleMedium),
                if (state.headerValidationStatus ==
                    SpHeaderValidationStatus.validating) ...[
                  const Gap(8),
                  Text(
                    context.loc.spHeaderValidationDescription,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
                const Gap(12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: context.appColors.surfaceContainerHighest,
                  color: failed
                      ? context.appColors.error
                      : context.appColors.success,
                ),
                const Gap(8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _progressLabel(context, state),
                        style: context.font.bodySmall?.copyWith(
                          color: failed
                              ? context.appColors.error
                              : context.appColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      context.loc.spHeaderValidationPercent('$percent'),
                      style: context.font.bodySmall?.copyWith(
                        color: failed
                            ? context.appColors.error
                            : context.appColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(BuildContext context, SpState state) {
    switch (state.headerValidationStatus) {
      case SpHeaderValidationStatus.idle:
        return context.loc.spHeaderValidationIdle;
      case SpHeaderValidationStatus.validating:
        return switch (state.headerValidationPhase) {
          SpHeaderValidationPhase.replay =>
            context.loc.spHeaderValidationReplay,
          SpHeaderValidationPhase.initialSync =>
            context.loc.spHeaderValidationInitialSync,
          null => context.loc.spHeaderValidationIdle,
        };
      case SpHeaderValidationStatus.valid:
        return context.loc.spHeaderValidationValid;
      case SpHeaderValidationStatus.failed:
        return context.loc.spHeaderValidationFailed;
    }
  }

  String _progressLabel(BuildContext context, SpState state) {
    final current = state.headerValidationCurrent;
    final total = state.headerValidationTo;
    if (current == null || total == null) return '';
    return context.loc.spHeaderValidationProgress('$current', '$total');
  }

  double _progressValue(SpState state) =>
      switch (state.headerValidationStatus) {
        SpHeaderValidationStatus.valid => 1.0,
        SpHeaderValidationStatus.validating => state.headerValidationProgress,
        SpHeaderValidationStatus.failed => state.headerValidationProgress,
        SpHeaderValidationStatus.idle => 0.0,
      };
}
