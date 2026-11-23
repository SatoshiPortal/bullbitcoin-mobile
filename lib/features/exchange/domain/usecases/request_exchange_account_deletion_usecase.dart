import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/exchange/domain/read_exchange_environment.dart';
import 'package:primitives/primitives.dart';
import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

/// Asks support to delete the account.
///
/// Uses the Exchange support capability and reports a contextual failure.
class RequestExchangeAccountDeletionUsecase {
  static const _message = 'I want to delete my account';

  final Preferences _settingsRepository;
  final Exchange _exchange;

  const RequestExchangeAccountDeletionUsecase({
    required this._exchange,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<void, ExchangeFailure>> execute() async {
    final allowed = await readExchangeEnvironment(
      _settingsRepository,
      ExchangeAccountDeletionRequestFailure.new,
    );
    if (allowed case Err(:final failure)) return Err(failure);
    final result = await _exchange.sendSupportMessage(text: _message);

    return result.mapErr(
      (failure) => ExchangeAccountDeletionRequestFailure(
        'sendSupportChatMessage failed: ${failure.runtimeType}',
      ),
    );
  }
}
