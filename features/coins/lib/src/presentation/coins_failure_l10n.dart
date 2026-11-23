import 'package:coins/src/coins_l10n.dart';
import 'package:coins/src/domain/coins_failure.dart';
import 'package:bull_ui/bull_ui.dart';

extension CoinsFailureL10n on CoinsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    CoinsLoadFailure() => context.loc.coinsErrorLoadFailed,
    CoinsFreezeFailure() => context.loc.coinsErrorFreezeFailed,
    CoinsUnfreezeFailure() => context.loc.coinsErrorUnfreezeFailed,
    CoinsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
