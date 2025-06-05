import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/exchange/domain/repositories/exchange_user_repository.dart';

class GetExchangeUserSummaryUsecase {
  final ExchangeUserRepository _exchangeUserRepository;

  GetExchangeUserSummaryUsecase({
    required ExchangeUserRepository exchangeUserRepository,
  }) : _exchangeUserRepository = exchangeUserRepository;

  Future<UserSummary> execute() async {
    try {
      final userSummary = await _exchangeUserRepository.getUserSummary();

      if (userSummary == null) {
        throw GetExchangeUserSummaryException('User summary is null');
      }

      return userSummary;
    } catch (e) {
      throw GetExchangeUserSummaryException('$e');
    }
  }
}

class GetExchangeUserSummaryException implements Exception {
  final String message;

  GetExchangeUserSummaryException(this.message);

  @override
  String toString() => '[GetUserSummaryUsecase]: $message';
}
