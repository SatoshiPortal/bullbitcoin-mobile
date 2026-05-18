import 'package:bb_mobile/core/transactions/application/transaction_port.dart';
import 'package:bb_mobile/core/transactions/application/build_transaction_usecase.dart';
import 'package:get_it/get_it.dart';

/// Dependency injection locator for the transaction feature.
///
/// [TransactionPort] is registered by the electrum module
/// ([ElectrumLocator.registerPorts]) since it is the infrastructure provider.
/// This locator only registers the use cases that consume the port.
class TransactionLocator {
  static void setup(GetIt locator) {
    _registerUseCases(locator);
  }

  static void _registerUseCases(GetIt locator) {
    locator.registerLazySingleton<BuildTransactionUsecase>(
      () =>
          BuildTransactionUsecase(transactionPort: locator<TransactionPort>()),
    );
  }
}
