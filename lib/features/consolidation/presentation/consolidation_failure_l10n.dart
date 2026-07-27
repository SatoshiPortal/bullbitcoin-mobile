import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/consolidation/domain/consolidation_failure.dart';
import 'package:flutter/widgets.dart';

extension ConsolidationFailureL10n on ConsolidationFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ConsolidationRequiredFailure() => context.loc.consolidationRequiredTitle,
    ConsolidationCountUnavailableFailure() =>
      context.loc.oopsSomethingWentWrong,
    ConsolidationBuildFailure() => context.loc.consolidationFailedBody,
    // Some batches already broadcast before this one failed — say so rather
    // than the generic "no transaction was broadcast" message, which would
    // be factually wrong here.
    ConsolidationSignFailure(:final succeededTxids)
        when succeededTxids.isNotEmpty =>
      context.loc.consolidationPartialFailureBody(succeededTxids.length),
    ConsolidationSignFailure() => context.loc.consolidationFailedBody,
    ConsolidationBroadcastFailure(:final succeededTxids)
        when succeededTxids.isNotEmpty =>
      context.loc.consolidationPartialFailureBody(succeededTxids.length),
    ConsolidationBroadcastFailure() => context.loc.consolidationFailedBody,
    ConsolidationUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
    ConsolidationSyncFailure() => context.loc.consolidationSyncRetryFailedBody,
  };
}
