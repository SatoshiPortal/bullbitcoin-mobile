import 'package:bull_logger/bull_logger.dart';
import 'package:exchange/exchange.dart';

import '../default_wallets_machine.dart';

/// Checks what the user typed as a default wallet of a network: a valid
/// destination is normalised, anything else is [WalletAddressInvalid]. A
/// check that throws is logged and answers [WalletAddressCheckFailed], never
/// a valid address.
class ValidateDefaultWalletDestinationUsecase {
  final Future<String?> Function(BtcNetwork type, String raw) _validate;

  const ValidateDefaultWalletDestinationUsecase(this._validate);

  Future<WalletAddressCheck> execute(BtcNetwork network, String text) async {
    try {
      return switch (await _validate(network, text)) {
        null => const WalletAddressInvalid(),
        final address => WalletAddressValid(address),
      };
    } on Exception catch (error) {
      log.warning('Failed to validate a default wallet: ${error.runtimeType}');
      return const WalletAddressCheckFailed();
    }
  }
}
