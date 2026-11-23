import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../default_wallets_failure.dart';

final class SaveDefaultWalletUsecase {
  final Exchange _exchange;

  const SaveDefaultWalletUsecase(this._exchange);

  @useResult
  Future<Result<DefaultWallet, DefaultWalletsFailure>> execute({
    required BtcNetwork walletType,
    required String address,
    String? existingRecipientId,
  }) async => switch (await _exchange.saveDefaultWallet(
    walletType: walletType,
    address: address,
    existingRecipientId: existingRecipientId,
  )) {
    WriteDone(:final value) => Ok(value),
    WriteOutcomeUnknown() => const Err(
      DefaultWalletsSaveOutcomeUnknownFailure(),
    ),
    WriteRefused() ||
    WriteNotSent() ||
    WriteSessionRejected() => const Err(DefaultWalletsSaveFailure()),
  };
}
