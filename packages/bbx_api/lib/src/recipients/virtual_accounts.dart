import 'package:meta/meta.dart';

/// The user's virtual IBAN account, with the server's raw values. The bank
/// details stay absent until the account is issued.
@immutable
class VirtualIban {
  final String? iban;
  final String? bicCode;
  final String? bankAddress;
  final String? ibanCountry;

  const VirtualIban({
    this.iban,
    this.bicCode,
    this.bankAddress,
    this.ibanCountry,
  });
}

/// The virtual payee part of a SEPA recipient.
@immutable
class SepaVirtualPayee {
  final String recipientId;

  /// Absent until a virtual payee exists, for example `ACTIVE` after.
  final String? virtualPayeeStatus;

  const SepaVirtualPayee({required this.recipientId, this.virtualPayeeStatus});
}

/// One page of the virtual payees of the user's SEPA recipients.
@immutable
class SepaVirtualPayeePage {
  /// The number of SEPA recipients over all pages, as sent.
  final num totalElements;
  final List<SepaVirtualPayee> payees;

  const SepaVirtualPayeePage({
    required this.totalElements,
    required this.payees,
  });
}
