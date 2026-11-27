import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:primitives/primitives.dart';

/// Checks a typed payout address with the host's bitcoin address
/// validation: a buy pays out on chain to a typed address.
class ValidateBuyAddressUsecase {
  final Future<String?> Function(String raw) _validateBitcoinAddress;

  const ValidateBuyAddressUsecase(this._validateBitcoinAddress);

  Future<Result<Destination, ExchangeFailure>> execute(String text) async =>
      switch (await _validateBitcoinAddress(text)) {
        final address? => Ok(DestinationAddress(BtcNetwork.bitcoin, address)),
        null => const Err(ExchangeDestinationInvalidFailure()),
      };
}
