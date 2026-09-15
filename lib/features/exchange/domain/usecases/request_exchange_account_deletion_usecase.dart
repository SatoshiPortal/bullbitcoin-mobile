import 'package:bb_mobile/core/exchange/domain/usecases/send_support_chat_message_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange/domain/exchange_failure.dart';
import 'package:meta/meta.dart';

/// Asks support to delete the account.
///
/// The support-chat use-case is already migrated and returns a `Result`, so
/// there is nothing to catch — its failure is lifted into this feature's
/// family so no other feature's type reaches the cubit.
class RequestExchangeAccountDeletionUsecase {
  static const _message = 'I want to delete my account';

  final SendSupportChatMessageUsecase _sendSupportChatMessageUsecase;

  const RequestExchangeAccountDeletionUsecase({
    required this._sendSupportChatMessageUsecase,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute() async {
    final result = await _sendSupportChatMessageUsecase.execute(text: _message);

    return result.mapErr(
      (failure) => ExchangeAccountDeletionRequestFailure(
        'sendSupportChatMessage failed: ${failure.runtimeType}',
      ),
    );
  }
}
