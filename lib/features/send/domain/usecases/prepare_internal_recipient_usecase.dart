import 'package:satoshifier/payment_request.dart';
import 'package:bb_mobile/features/wallet/public/recipient_wallet.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

import '../internal_recipient_policy.dart';
import '../send_failure.dart';

typedef PreparedInternalRecipient = ({Wallet wallet, String address});

class PrepareInternalRecipientUsecase {
  final WalletFacade _wallet;

  const PrepareInternalRecipientUsecase(this._wallet);

  @useResult
  Future<Result<PreparedInternalRecipient, SendFailure>> execute({
    required String walletId,
    required List<Wallet> wallets,
    required PaymentRequest? request,
    required Set<String> excludedAddresses,
    String? fixedSourceWalletId,
  }) async {
    final wallet = wallets.where((wallet) => wallet.id == walletId).firstOrNull;
    if (wallet == null ||
        !const InternalRecipientPolicy().permits(
          wallet,
          request,
          fixedSourceWalletId: fixedSourceWalletId,
        )) {
      return const Err(
        SendAddressNetworkMismatchFailure('internal recipient unavailable'),
      );
    }
    final result = await _wallet.nextReceiveAddress(
      walletId,
      excludedAddresses: excludedAddresses,
    );
    return switch (result) {
      Ok(:final value)
          when !excludedAddresses.contains(value) && value.isNotEmpty =>
        Ok((wallet: wallet, address: value)),
      _ => const Err(
        SendInvalidPaymentRequestFailure(
          logMessage: 'internal receive address unavailable',
        ),
      ),
    };
  }
}
