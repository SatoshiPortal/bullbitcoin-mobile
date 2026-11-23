import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';
import 'package:meta/meta.dart';

import '../exchange_support_chat_failure.dart';

/// Resolves who "I" am in the support thread.
class ResolveSupportChatUserIdUsecase {
  final Exchange _exchange;

  const ResolveSupportChatUserIdUsecase({required this._exchange});

  @useResult
  Future<Result<String?, ExchangeSupportChatFailure>> execute() async =>
      (await _exchange.getUserSummary())
          .map((summary) => summary.userId)
          .mapErr((_) => const ExchangeSupportChatUnexpectedFailure());
}
