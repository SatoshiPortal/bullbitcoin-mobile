import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:meta/meta.dart';

/// Resolves who "I" am in the support thread.
///
/// [GetExchangeUserSummaryUsecase] is shared by ten features and still throws, so this feature-owned use-case is the boundary that maps it to a failure. That is the staged alternative to migrating a high fan-out core dependency in one go.
class ResolveSupportChatUserIdUsecase {
  final GetExchangeUserSummaryUsecase _getUserSummaryUsecase;

  ResolveSupportChatUserIdUsecase({required this._getUserSummaryUsecase});

  @useResult
  Future<Result<String?, ExchangeSupportChatFailure>> execute() async {
    try {
      final userSummary = await _getUserSummaryUsecase.execute();
      return Ok(userSummary.userId);
    } catch (e, st) {
      log.warning(
        'Failed to resolve support chat user id',
        error: e,
        trace: st,
      );
      return Err(ExchangeSupportChatUnexpectedFailure('$e'));
    }
  }
}
