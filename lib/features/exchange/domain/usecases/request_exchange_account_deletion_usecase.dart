import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/send_support_chat_message_usecase.dart';
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

  final SettingsRepository? _settingsRepository;
  final SendSupportChatMessageUsecase _sendSupportChatMessageUsecase;

  const RequestExchangeAccountDeletionUsecase({
    required this._sendSupportChatMessageUsecase,
    this._settingsRepository,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute() async {
    final settingsRepository = _settingsRepository;
    if (settingsRepository == null) {
      return const Err(ExchangeAccountDeletionRequestFailure());
    }
    final allowed = await readExchangeEnvironment(
      settingsRepository,
      ExchangeAccountDeletionRequestFailure.new,
    );
    if (allowed case Err(:final failure)) return Err(failure);
    final result = await _sendSupportChatMessageUsecase.execute(text: _message);

    return result.mapErr(
      (failure) => ExchangeAccountDeletionRequestFailure(
        'sendSupportChatMessage failed: ${failure.runtimeType}',
      ),
    );
  }
}
