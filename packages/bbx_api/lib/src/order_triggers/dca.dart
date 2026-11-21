import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';

/// How often a recurring buy runs.
enum DcaFrequency {
  hourly('HOURLY'),
  daily('DAILY'),
  weekly('WEEKLY'),
  monthly('MONTHLY');

  /// The wire value.
  final String value;

  const DcaFrequency(this.value);
}

/// Where a recurring buy pays out.
enum DcaRecipientType {
  bitcoinAddress('OUT_BITCOIN_ADDRESS'),
  lightningAddress('OUT_LIGHTNING_ADDRESS'),
  liquidAddress('OUT_LIQUID_ADDRESS');

  /// The wire value.
  final String value;

  const DcaRecipientType(this.value);
}

/// A recurring buy as `api-ordertrigger` returns it, with the server's raw
/// values: the amount, frequency, recipient type and dates are unparsed.
@immutable
class Dca {
  final String userId;
  final int userNbr;
  final String amountStr;
  final String currencyCode;

  /// For example `WEEKLY`.
  final String recurringFrequency;

  /// For example `OUT_BITCOIN_ADDRESS`.
  final String recipientType;
  final String nextRunAt;
  final String createdAt;
  final String address;

  const Dca({
    required this.userId,
    required this.userNbr,
    required this.amountStr,
    required this.currencyCode,
    required this.recurringFrequency,
    required this.recipientType,
    required this.nextRunAt,
    required this.createdAt,
    required this.address,
  });

  /// Throws a [BbxApiFormatException] naming the first invalid field.
  factory Dca.fromJson(Map<String, dynamic> json) => Dca(
    userId: read<String>(json['userId'], 'userId'),
    userNbr: read<num>(json['userNbr'], 'userNbr').toInt(),
    amountStr: read<String>(json['amountStr'], 'amountStr'),
    currencyCode: read<String>(json['currencyCode'], 'currencyCode'),
    recurringFrequency: read<String>(
      json['recurringFrequency'],
      'recurringFrequency',
    ),
    recipientType: read<String>(json['recipientType'], 'recipientType'),
    nextRunAt: read<String>(json['nextRunAt'], 'nextRunAt'),
    createdAt: read<String>(json['createdAt'], 'createdAt'),
    address: read<String>(json['address'], 'address'),
  );
}
