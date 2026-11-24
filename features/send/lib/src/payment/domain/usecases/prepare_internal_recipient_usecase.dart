import 'package:satoshifier/payment_request.dart';
import 'package:send/src/payment/domain/send_source.dart';
import 'package:receive/receive.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

import '../internal_recipient_policy.dart';

import 'package:send/send.dart';

typedef PreparedInternalRecipient = ({SendSource wallet, String address});

class PrepareInternalRecipientUsecase {
  final Receive _receive;

  const PrepareInternalRecipientUsecase(this._receive);

  @useResult
  Future<Result<PreparedInternalRecipient, SendFailure>> execute({
    required String walletId,
    required List<SendSource> wallets,
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
    final result = await _receive.nextUnusedAddress(
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
