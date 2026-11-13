import 'package:bb_mobile/features/fund_exchange/domain/fund_exchange_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

/// Opens a link outside the app. The implementation owns the platform call and
/// is the `try/catch` boundary for it, so nothing raw reaches the use-case.
abstract interface class ExternalLinkPort {
  @useResult
  Future<Result<void, FundExchangeFailure>> open(Uri url);
}
