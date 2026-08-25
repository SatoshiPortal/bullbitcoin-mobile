import 'package:bb_mobile/core/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/usecases/resolve_support_chat_user_id_usecase.dart';
import 'package:get_it/get_it.dart';

class ExchangeSupportChatLocator {
  static void setup(GetIt locator) {
    _registerUsecases(locator);
  }

  static void _registerUsecases(GetIt locator) {
    locator.registerFactory<ResolveSupportChatUserIdUsecase>(
      () => ResolveSupportChatUserIdUsecase(
        getUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );
  }
}
