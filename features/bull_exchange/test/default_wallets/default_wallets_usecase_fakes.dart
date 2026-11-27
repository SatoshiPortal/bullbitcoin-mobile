import 'package:bull_exchange/src/default_wallets/domain/default_wallets_machine.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/get_default_wallets_usecase.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/save_default_wallet_usecase.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/unset_default_wallet_usecase.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/validate_default_wallet_destination_usecase.dart';
import 'package:bull_exchange/src/default_wallets/domain/usecases/verify_default_wallets_usecase.dart';
import 'package:exchange/exchange.dart';
import 'package:primitives/primitives.dart';

final class FakeGetDefaultWalletsUsecase implements GetDefaultWalletsUsecase {
  final Future<Result<DefaultWallets, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeGetDefaultWalletsUsecase(this.answer);

  @override
  Future<Result<DefaultWallets, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}

final class FakeValidateDefaultWalletDestinationUsecase
    implements ValidateDefaultWalletDestinationUsecase {
  final Future<WalletAddressCheck> Function(BtcNetwork network, String text)
  answer;

  FakeValidateDefaultWalletDestinationUsecase(this.answer);

  @override
  Future<WalletAddressCheck> execute(BtcNetwork network, String text) =>
      answer(network, text);
}

final class FakeSaveDefaultWalletUsecase implements SaveDefaultWalletUsecase {
  final Future<GatedWrite<Result<DefaultWallet, ExchangeWriteFailure>>>
  Function(
    ExchangeSession session, {
    required BtcNetwork network,
    required String address,
    String? existingRecipientId,
  })
  answer;

  FakeSaveDefaultWalletUsecase(this.answer);

  @override
  Future<GatedWrite<Result<DefaultWallet, ExchangeWriteFailure>>> execute(
    ExchangeSession session, {
    required BtcNetwork network,
    required String address,
    String? existingRecipientId,
  }) => answer(
    session,
    network: network,
    address: address,
    existingRecipientId: existingRecipientId,
  );
}

final class FakeUnsetDefaultWalletUsecase implements UnsetDefaultWalletUsecase {
  final Future<GatedWrite<Result<void, ExchangeWriteFailure>>> Function(
    ExchangeSession session, {
    required BtcNetwork network,
    required String recipientId,
    required String address,
  })
  answer;

  FakeUnsetDefaultWalletUsecase(this.answer);

  @override
  Future<GatedWrite<Result<void, ExchangeWriteFailure>>> execute(
    ExchangeSession session, {
    required BtcNetwork network,
    required String recipientId,
    required String address,
  }) => answer(
    session,
    network: network,
    recipientId: recipientId,
    address: address,
  );
}

final class FakeVerifyDefaultWalletsUsecase
    implements VerifyDefaultWalletsUsecase {
  final Future<Result<DefaultWallets, ExchangeReadFailure>> Function(
    ExchangeSession session,
  )
  answer;

  FakeVerifyDefaultWalletsUsecase(this.answer);

  @override
  Future<Result<DefaultWallets, ExchangeReadFailure>> execute(
    ExchangeSession session,
  ) => answer(session);
}
