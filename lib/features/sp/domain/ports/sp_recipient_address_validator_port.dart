import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

enum SpRecipientAddressType { silentPayment, standard }

abstract interface class SpRecipientAddressValidatorPort {
  @useResult
  Future<Result<SpRecipientAddressType, SpFailure>> validateRecipientAddress(
    String address,
    BitcoinNetwork network,
  );
}
