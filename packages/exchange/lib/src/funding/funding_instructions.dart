import 'package:meta/meta.dart';

/// A value of funding instructions the user copies into their bank. What a
/// field is called on screen is the rail's copy (one field can read
/// "beneficiary name" on one rail and "recipient name" on another).
enum InstructionField {
  beneficiaryName,
  beneficiaryEmail,

  /// The e-Transfer security question (the server's `code`).
  secretQuestion,

  /// The e-Transfer security answer: the account's user number.
  secretAnswer,

  /// The reference the payment must carry (the server's `code`).
  transferCode,
  bankAccountDetails,
  swift,
  institutionNumber,
  transitNumber,
  routingNumber,
  beneficiaryAddress,
  bankName,
  bankAddress,
  billerName,
  iban,
  bic,
  bankAccountCountry,
  bankCountry,
  clabe,
  phoneNumber,
  cedulaJuridica,
  cvu,
}

@immutable
final class InstructionRow {
  final InstructionField field;
  final String value;

  const InstructionRow(this.field, this.value);

  @override
  bool operator ==(Object other) =>
      other is InstructionRow && other.field == field && other.value == value;

  @override
  int get hashCode => Object.hash(field, value);

  @override
  String toString() => 'InstructionRow(${field.name})';
}

/// What a rail shows once the exchange answered. Every value is the
/// server's; nothing is a default (FUND-1).
@immutable
sealed class FundingInstructions {
  const FundingInstructions();
}

final class FundingInstructionRows extends FundingInstructions {
  final List<InstructionRow> rows;

  const FundingInstructionRows(this.rows);

  @override
  bool operator ==(Object other) {
    if (other is! FundingInstructionRows || other.rows.length != rows.length) {
      return false;
    }
    for (var i = 0; i < rows.length; i++) {
      if (other.rows[i] != rows[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(rows);
}

/// Canada Post: a code shown as a QR code.
final class FundingInstructionQr extends FundingInstructions {
  final String payload;

  const FundingInstructionQr(this.payload);

  @override
  bool operator ==(Object other) =>
      other is FundingInstructionQr && other.payload == payload;

  @override
  int get hashCode => payload.hashCode;
}

/// COP: a web page that takes the payment. Only `http`/`https` links exist.
final class FundingInstructionLink extends FundingInstructions {
  final Uri link;

  const FundingInstructionLink(this.link);

  @override
  bool operator ==(Object other) =>
      other is FundingInstructionLink && other.link == link;

  @override
  int get hashCode => link.hashCode;
}
