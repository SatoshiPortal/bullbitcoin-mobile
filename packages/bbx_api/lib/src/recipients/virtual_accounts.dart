import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
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

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory VirtualIban.fromJson(Map<String, dynamic> json) => VirtualIban(
    iban: read<String?>(json['iban'], 'iban'),
    bicCode: read<String?>(json['bicCode'], 'bicCode'),
    bankAddress: read<String?>(json['bankAddress'], 'bankAddress'),
    ibanCountry: read<String?>(json['ibanCountry'], 'ibanCountry'),
  );
}

/// The virtual payee part of a SEPA recipient.
@immutable
class SepaVirtualPayee {
  final String recipientId;

  /// Absent until a virtual payee exists, for example `ACTIVE` after.
  final String? virtualPayeeStatus;

  const SepaVirtualPayee({required this.recipientId, this.virtualPayeeStatus});

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory SepaVirtualPayee.fromJson(Map<String, dynamic> json) =>
      SepaVirtualPayee(
        recipientId: read<String>(json['recipientId'], 'recipientId'),
        virtualPayeeStatus: read<String?>(
          json['virtualPayeeStatus'],
          'virtualPayeeStatus',
        ),
      );
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
