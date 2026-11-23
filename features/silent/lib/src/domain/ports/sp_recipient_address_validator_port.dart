import 'package:silent/src/domain/silent_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

enum SpRecipientAddressType { silentPayment, standard }

abstract interface class SpRecipientAddressValidatorPort {
  @useResult
  Future<Result<SpRecipientAddressType, SilentFailure>>
  validateRecipientAddress(String address, BitcoinNetwork network);
}
