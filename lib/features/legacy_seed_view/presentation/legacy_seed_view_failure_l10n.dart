import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/legacy_seed_view/domain/legacy_seed_view_failure.dart';
import 'package:flutter/widgets.dart';

extension LegacySeedViewFailureL10n on LegacySeedViewFailure {
  String toTranslated(BuildContext context) => switch (this) {
    LegacySeedViewFetchFailure() => context.loc.legacySeedViewErrorFetch,
    LegacySeedViewUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
