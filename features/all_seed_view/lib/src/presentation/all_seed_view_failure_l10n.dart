import 'package:all_seed_view/src/localizations.dart';
import 'package:all_seed_view/src/domain/all_seed_view_failure.dart';
import 'package:flutter/widgets.dart';

extension AllSeedViewFailureL10n on AllSeedViewFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AllSeedViewCustodyMetadataFailure() =>
      context.loc.parentCustodyMetadataUnavailable,
    AllSeedViewFetchFailure() => context.loc.allSeedViewErrorFetch,
    AllSeedViewDeleteFailure() => context.loc.allSeedViewErrorDelete,
  };
}
