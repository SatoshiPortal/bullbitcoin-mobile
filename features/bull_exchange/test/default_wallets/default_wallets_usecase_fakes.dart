import 'package:bull_exchange/src/default_wallets/domain/usecases/get_default_wallets_usecase.dart';
import 'package:exchange/exchange.dart';

final class FakeGetDefaultWalletsUsecase implements GetDefaultWalletsUsecase {
  final Future<ExchangeRead<DefaultWallets>> Function() answer;

  FakeGetDefaultWalletsUsecase(this.answer);

  @override
  Future<ExchangeRead<DefaultWallets>> execute() => answer();
}
