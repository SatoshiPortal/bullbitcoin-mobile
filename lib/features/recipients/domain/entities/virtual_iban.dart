import 'package:bb_mobile/features/recipients/domain/value_objects/virtual_iban_status.dart';

class VirtualIban {
  final VirtualIbanStatus status;
  final String? iban;
  final String? bicCode;
  final String? bankAddress;
  final String? ibanCountry;

  const VirtualIban({
    required this.status,
    this.iban,
    this.bicCode,
    this.bankAddress,
    this.ibanCountry,
  });

  const VirtualIban.absent() : this(status: VirtualIbanStatus.absent);
}
