import 'entities/recipient_details.dart';

/// The fields that tell one fiat recipient from another of the same type,
/// without secrets (no Interac answer) and without display-only text. Values
/// are normalised (no whitespace, lower case) so a server that reformats a
/// number still matches.
Map<String, String> recipientIdentity(RecipientDetails details) {
  final fields = switch (details) {
    InteracEmailCadDetails(:final email) => {'email': email},
    BillPaymentCadDetails(:final payeeCode, :final payeeAccountNumber) => {
      'payeeCode': payeeCode,
      'payeeAccountNumber': payeeAccountNumber,
    },
    BankTransferCadDetails(
      :final institutionNumber,
      :final transitNumber,
      :final accountNumber,
    ) =>
      {
        'institutionNumber': institutionNumber,
        'transitNumber': transitNumber,
        'accountNumber': accountNumber,
      },
    SepaEurDetails(:final iban) => {'iban': iban},
    SpeiClabeMxnDetails(:final clabe) => {'clabe': clabe},
    SpeiSmsMxnDetails(:final institutionCode, :final phone) => {
      'institutionCode': institutionCode,
      'phone': phone,
    },
    SpeiCardMxnDetails(:final institutionCode, :final debitcard) => {
      'institutionCode': institutionCode,
      'debitcard': debitcard,
    },
    SinpeIbanUsdDetails(:final iban) => {'iban': iban},
    SinpeIbanCrcDetails(:final iban) => {'iban': iban},
    SinpeMovilCrcDetails(:final phoneNumber) => {'phoneNumber': phoneNumber},
    BankAccountArgentinaDetails(:final claveUniform) => {
      'claveUniform': claveUniform,
    },
    PseColombiaDetails(:final bankCode, :final bankAccount) => {
      'bankCode': bankCode,
      'bankAccount': bankAccount,
    },
    NequiColombiaDetails(:final phoneNumber) => {'phoneNumber': phoneNumber},
  };
  return {
    'type': details.type.name,
    for (final MapEntry(:key, :value) in fields.entries)
      key: value.replaceAll(RegExp(r'\s'), '').toLowerCase(),
  };
}
