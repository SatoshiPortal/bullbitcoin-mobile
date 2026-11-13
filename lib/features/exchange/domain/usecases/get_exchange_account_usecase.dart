import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:primitives/primitives.dart';
import '../exchange_access.dart';
import '../exchange_failure.dart';
import '../read_exchange_environment.dart';
import '../repositories/exchange_access_repository.dart';
import '../repositories/exchange_account_repository.dart';
import 'expire_exchange_session_usecase.dart';

/// Only a current, server-rejected request may expire a credential.
class GetExchangeAccountUsecase {
  const GetExchangeAccountUsecase({
    required ExchangeAccountRepository mainnetAccountRepository,
    required ExchangeAccountRepository testnetAccountRepository,
    required SettingsRepository settingsRepository,
    required this._access,
    required this._expire,
  }) : _mainnet = mainnetAccountRepository,
       _testnet = testnetAccountRepository,
       _settings = settingsRepository;

  final ExchangeAccountRepository _mainnet;
  final ExchangeAccountRepository _testnet;
  final SettingsRepository _settings;
  final ExchangeAccessRepository _access;
  final ExpireExchangeSessionUsecase _expire;

  Future<Result<UserSummary, ExchangeFailure>> execute() async {
    if (_access.current case ExchangeAccessEnabled(
      session: ExchangeAccessSession.signedIn,
    )) {
      final epoch = _access.epoch;
      final environment = await readExchangeEnvironment(
        _settings,
        ExchangeAccountUnavailableFailure.new,
      );
      if (_access.epoch != epoch) {
        return const Err(ExchangeOperationStaleFailure());
      }
      if (environment case Err(:final failure)) return Err(failure);
      final isTestnet = (environment as Ok).value.isTestnet as bool;
      final result = await (isTestnet ? _testnet : _mainnet).getAccount();
      if (_access.epoch != epoch) {
        return const Err(ExchangeOperationStaleFailure());
      }
      if (result case Err(failure: ExchangeSessionRejectedFailure())) {
        final expired = await _expire.execute(
          epoch: epoch,
          isTestnet: isTestnet,
        );
        if (expired case Err(:final failure)) return Err(failure);
      }
      return result;
    }
    return const Err(ExchangeNotAuthenticatedFailure());
  }
}
