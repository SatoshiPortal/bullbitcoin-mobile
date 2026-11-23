import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/domain/usecases/get_exchange_user_summary_usecase.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/recipients/public/recipients_facade.dart';
import 'package:bb_mobile/features/withdraw/domain/confirm_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/create_withdraw_order_usecase.dart';
import 'package:bb_mobile/features/withdraw/domain/load_withdraw_context_usecase.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:get_it/get_it.dart';

class WithdrawLocator {
  static void setup(GetIt locator) {
    registerUsecases(locator);
    registerBlocs(locator);
  }

  static void registerUsecases(GetIt locator) {
    locator.registerLazySingleton<LoadWithdrawContextUsecase>(
      () => LoadWithdrawContextUsecase(
        getExchangeUserSummaryUsecase: locator<GetExchangeUserSummaryUsecase>(),
      ),
    );

    locator.registerLazySingleton<CreateWithdrawOrderUsecase>(
      () => CreateWithdrawOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
      ),
    );

    locator.registerFactory<ConfirmWithdrawOrderUsecase>(
      () => ConfirmWithdrawOrderUsecase(
        exchange: locator<Exchange>(),
        settingsRepository: locator<Preferences>(),
        recipientsFacade: locator<RecipientsFacade>(),
      ),
    );
  }

  static void registerBlocs(GetIt locator) {
    locator.registerFactory<WithdrawBloc>(
      () => WithdrawBloc(
        loadWithdrawContextUsecase: locator<LoadWithdrawContextUsecase>(),
        createWithdrawOrderUsecase: locator<CreateWithdrawOrderUsecase>(),
        confirmWithdrawOrderUsecase: locator<ConfirmWithdrawOrderUsecase>(),
      ),
    );
  }
}
