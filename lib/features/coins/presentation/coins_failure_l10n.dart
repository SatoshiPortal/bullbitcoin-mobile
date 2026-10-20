import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/coins/domain/coins_failure.dart';
import 'package:flutter/widgets.dart';

extension CoinsFailureL10n on CoinsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    CoinsLoadFailure() => context.loc.coinsErrorLoadFailed,
    CoinsFreezeFailure() => context.loc.coinsErrorFreezeFailed,
    CoinsUnfreezeFailure() => context.loc.coinsErrorUnfreezeFailed,
    CoinsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
