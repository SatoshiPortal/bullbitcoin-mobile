import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/presentation/bloc/send_cubit.dart';
import 'package:bb_mobile/features/send/presentation/send_failure_l10n.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SendError extends StatelessWidget {
  const SendError({super.key});

  @override
  Widget build(BuildContext context) {
    final failure = context.select((SendCubit cubit) => cubit.state.failure);
    final buildError = failure is SendTransactionBuildFailure;
    final confirmError = failure is SendTransactionConfirmationFailure
        ? failure
        : null;

    if (buildError) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: BBText(
          context.loc.sendErrorBuildFailed,
          style: context.font.bodyLarge,
          color: context.appColors.error,
          maxLines: 5,
          textAlign: TextAlign.center,
        ),
      );
    }
    if (confirmError != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            BBText(
              context.loc.sendErrorConfirmationFailed,
              style: context.font.bodyLarge,
              color: context.appColors.error,
              maxLines: 5,
              textAlign: TextAlign.center,
            ),
            if (confirmError.isBroadcastFailure) ...[
              const Gap(8),
              BBText(
                context.loc.sendErrorBroadcastFailed,
                style: context.font.bodyMedium,
                color: context.appColors.error,
                maxLines: 5,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }
    if (failure is SendPersistenceFailure ||
        failure is SendPendingTransactionChangedFailure ||
        failure is SendStoredTransactionInvalidFailure) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: BBText(
          failure!.toTranslated(context),
          style: context.font.bodyMedium,
          color: context.appColors.error,
          maxLines: 3,
          textAlign: TextAlign.center,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
