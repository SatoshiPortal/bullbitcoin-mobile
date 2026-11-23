import 'package:bull_ui/bull_ui.dart'
    show BullShapesX, BullThemeX, BullTypographyX, Gap;
import 'package:silent/src/presentation/silent_l10n.dart';
import 'package:silent/src/domain/entities/sp_notification.dart';
import 'package:silent/src/presentation/sp_cubit.dart';
import 'package:silent/src/presentation/sp_state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpHeaderValidationScreen extends StatelessWidget {
  const SpHeaderValidationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpCubit>().state;
    final invalidChain =
        state.headerValidationStatus == SpHeaderValidationStatus.invalidChain;
    final failed =
        invalidChain ||
        state.headerValidationStatus == SpHeaderValidationStatus.failed;
    final progress = _progressValue(state);
    final percent = (progress * 100).round();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.silentLoc.silentHeaderValidationTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
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
                  ? context.bull.errorContainer
                  : context.bull.surface,
              borderRadius: BorderRadius.circular(context.bullShapes.card),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title(context, state),
                  style: context.bullType.body.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (state.headerValidationStatus ==
                    SpHeaderValidationStatus.validating) ...[
                  const Gap(8),
                  Text(
                    context.silentLoc.silentHeaderValidationDescription,
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.bull.textMuted),
                  ),
                ],
                if (invalidChain) ...[
                  const Gap(8),
                  Text(
                    context.silentLoc.silentHeaderValidationInvalidChainDetail,
                    style: context.bullType.label
                        .copyWith(fontWeight: FontWeight.w400)
                        .copyWith(color: context.bull.error),
                  ),
                ],
                // The chain was wiped, so there is no progress to show.
                if (!invalidChain) ...[
                  const Gap(12),
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: context.bull.surfaceContainerHighest,
                    color: failed ? context.bull.error : context.bull.success,
                  ),
                  const Gap(8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _progressLabel(context, state),
                          style: context.bullType.label
                              .copyWith(fontWeight: FontWeight.w400)
                              .copyWith(
                                color: failed
                                    ? context.bull.error
                                    : context.bull.textMuted,
                              ),
                        ),
                      ),
                      Text(
                        context.silentLoc.silentScanPercent('$percent'),
                        style: context.bullType.label
                            .copyWith(fontWeight: FontWeight.w400)
                            .copyWith(
                              color: failed
                                  ? context.bull.error
                                  : context.bull.textMuted,
                            ),
                      ),
                    ],
                  ),
                ],
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
        return context.silentLoc.silentHeaderValidationIdle;
      case SpHeaderValidationStatus.validating:
        return switch (state.headerValidationPhase) {
          SpHeaderValidationPhase.replay =>
            context.silentLoc.silentHeaderValidationReplay,
          SpHeaderValidationPhase.initialSync =>
            context.silentLoc.silentHeaderValidationInitialSync,
          null => context.silentLoc.silentHeaderValidationIdle,
        };
      case SpHeaderValidationStatus.reconnecting:
        return context.silentLoc.silentHeaderValidationReconnecting;
      case SpHeaderValidationStatus.valid:
        return context.silentLoc.silentHeaderValidationValid;
      case SpHeaderValidationStatus.failed:
        return context.silentLoc.silentHeaderValidationFailed;
      case SpHeaderValidationStatus.invalidChain:
        return context.silentLoc.silentHeaderValidationInvalidChain;
    }
  }

  String _progressLabel(BuildContext context, SpState state) {
    final current = state.headerValidationCurrent;
    final total = state.headerValidationTo;
    if (current == null || total == null) return '';
    return context.silentLoc.silentScanBlockProgress('$current', '$total');
  }

  double _progressValue(SpState state) =>
      switch (state.headerValidationStatus) {
        SpHeaderValidationStatus.valid => 1.0,
        SpHeaderValidationStatus.validating => state.headerValidationProgress,
        SpHeaderValidationStatus.reconnecting => state.headerValidationProgress,
        SpHeaderValidationStatus.failed => state.headerValidationProgress,
        SpHeaderValidationStatus.invalidChain => 0.0,
        SpHeaderValidationStatus.idle => 0.0,
      };
}
