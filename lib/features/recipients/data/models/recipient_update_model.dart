import 'package:bb_mobile/features/recipients/domain/interac_security_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_details.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';

final class RecipientUpdateModel {
  const RecipientUpdateModel._(this.element);

  final Map<String, dynamic> element;

  factory RecipientUpdateModel.fromDetails(
    String recipientId,
    RecipientDetails details,
  ) {
    final commonFields = <String, dynamic>{
      'recipientId': recipientId,
      'recipientType': details.type.apiValue,
      'label': details.label,
      if (details.isOwner != null) 'isOwner': details.isOwner,
    };

    final typeFields = switch (details) {
      InteracEmailCadDetails details => <String, dynamic>{
        'email': details.email,
        'name': details.name,
        'securityQuestion': details.securityQuestion,
        'securityAnswer': details.securityAnswer,
      },
      BillPaymentCadDetails details => <String, dynamic>{
        'payeeAccountNumber': details.payeeAccountNumber,
      },
      BankTransferCadDetails details => <String, dynamic>{
        'institutionNumber': details.institutionNumber,
        'transitNumber': details.transitNumber,
        'accountNumber': details.accountNumber,
        'name': details.name,
        'defaultComment': details.defaultComment,
      },
      SepaEurDetails details => <String, dynamic>{
        'iban': details.iban,
        'firstname': details.firstname,
        'lastname': details.lastname,
        'corporateName': details.corporateName,
      },
      SpeiClabeMxnDetails details => <String, dynamic>{
        'clabe': details.clabe,
        'name': details.name,
      },
      SpeiSmsMxnDetails details => <String, dynamic>{
        'institutionCode': details.institutionCode,
        'phone': details.phone,
        'name': details.name,
      },
      SpeiCardMxnDetails details => <String, dynamic>{
        'institutionCode': details.institutionCode,
        'debitcard': details.debitcard,
        'name': details.name,
      },
      SinpeIbanUsdDetails details => <String, dynamic>{
        'iban': details.iban,
        'currency': details.type.currencyCode,
      },
      SinpeIbanCrcDetails details => <String, dynamic>{
        'iban': details.iban,
        'currency': details.type.currencyCode,
      },
      SinpeMovilCrcDetails details => <String, dynamic>{
        'phoneNumber': details.phoneNumber,
      },
      BankAccountArgentinaDetails details => <String, dynamic>{
        'claveUniform': details.claveUniform,
        'name': details.name,
      },
      PseColombiaDetails details => <String, dynamic>{
        'accountType': details.accountType,
        'bankAccount': details.bankAccount,
        'bankCode': details.bankCode,
        'documentId': details.documentId,
        'documentType': details.documentType,
        'name': details.name,
        'lastname': details.lastname,
        'email': details.email,
        'isCorporate': details.isCorporate,
        'corporateName': details.corporateName,
      },
      NequiColombiaDetails details => <String, dynamic>{
        'bankAccount': details.phoneNumber,
        'documentId': details.documentId,
        'documentType': details.documentType,
        'name': details.name,
        'lastname': details.lastname,
        'email': details.email,
        'isCorporate': details.isCorporate,
        'corporateName': details.corporateName,
      },
      _ => throw UnsupportedError(
        'Unsupported recipient details type: ${details.runtimeType}',
      ),
    };

    return RecipientUpdateModel._({...commonFields, ...typeFields});
  }

  factory RecipientUpdateModel.fromInteracSecurityDetails(
    InteracSecurityDetails details,
  ) {
    return RecipientUpdateModel._({
      'recipientId': details.recipientId,
      'recipientType': RecipientType.interacEmailCad.apiValue,
      'email': details.email,
      'securityQuestion': details.securityQuestion,
      'securityAnswer': details.securityAnswer,
    });
  }
}

extension on RecipientType {
  String get apiValue => switch (this) {
    RecipientType.interacEmailCad => 'OUT_INTERAC_EMAIL',
    RecipientType.billPaymentCad => 'OUT_BILL_PAYMENT_CA',
    RecipientType.bankTransferCad => 'OUT_BANK_ACCOUNT_EFT_CA',
    RecipientType.sepaEur => 'OUT_SEPA',
    RecipientType.speiClabeMxn => 'OUT_BITSO_CLABE',
    RecipientType.speiSmsMxn => 'OUT_BITSO_PHONE',
    RecipientType.speiCardMxn => 'OUT_BITSO_CARD',
    RecipientType.sinpeIbanUsd || RecipientType.sinpeIbanCrc => 'IBAN_CR',
    RecipientType.sinpeMovilCrc => 'SINPE_MOVIL',
    RecipientType.bankAccountArgentina => 'OUT_CLAVE_UNIFORM',
    RecipientType.pseColombia => 'OUT_COP_BANK_ACCOUNT',
    RecipientType.nequiColombia => 'OUT_COP_NEQUI',
  };
}
