import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/all_seed_view/domain/all_seed_view_failure.dart';
import 'package:flutter/widgets.dart';

extension AllSeedViewFailureL10n on AllSeedViewFailure {
  String toTranslated(BuildContext context) => switch (this) {
        AllSeedViewFetchFailure() => context.loc.allSeedViewErrorFetch,
        AllSeedViewDeleteFailure() => context.loc.allSeedViewErrorDelete,
        AllSeedViewUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
      };
}
