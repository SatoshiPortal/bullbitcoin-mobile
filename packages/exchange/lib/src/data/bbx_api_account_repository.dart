import 'package:bbx_api/bbx_api.dart' as bbx;
import 'package:primitives/primitives.dart' show Result;

import '../domain/entities/user_summary.dart';
import '../domain/exchange_failure.dart';
import 'read_user_summary.dart';

final class BbxApiAccountRepository {
  final bbx.Bbx _api;

  const BbxApiAccountRepository(this._api);

  /// The signed-in account, through the one `getUserSummary` classification.
  /// An unreadable key is an unavailable account, not a logout.
  Future<Result<UserSummary, ExchangeFailure>> getAccount() async =>
      userSummaryResult(
        await readUserSummary(_api),
        credentialUnavailable: ExchangeAccountUnavailableFailure.new,
      );
}
