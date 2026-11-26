import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/recipients/cad_biller.dart';
import 'package:bbx_api/src/recipients/fiat_recipient.dart';
import 'package:bbx_api/src/recipients/institution.dart';
import 'package:bbx_api/src/recipients/my_recipient.dart';
import 'package:bbx_api/src/recipients/new_fiat_recipient.dart';
import 'package:bbx_api/src/recipients/payment_processor_details.dart';
import 'package:bbx_api/src/recipients/virtual_accounts.dart';

/// Throws a [BbxFormatException] naming the first invalid field.
CadBiller parseCadBiller(Map<String, dynamic> json) => CadBiller(
  payeeCode: read<String>(json['payeeCode'], 'payeeCode'),
  payeeName: read<String>(json['payeeName'], 'payeeName'),
);

/// Throws a [BbxFormatException] naming the first invalid field.
FiatRecipient parseFiatRecipient(Map<String, dynamic> json) {
  String? text(String field) => read<String?>(json[field], field);
  bool? flag(String field) => read<bool?>(json[field], field);
  return FiatRecipient(
    recipientId: read<String>(json['recipientId'], 'recipientId'),
    userId: read<String>(json['userId'], 'userId'),
    userNbr: read<int>(json['userNbr'], 'userNbr'),
    isArchived: read<bool>(json['isArchived'], 'isArchived'),
    createdAt: read<String>(json['createdAt'], 'createdAt'),
    updatedAt: read<String>(json['updatedAt'], 'updatedAt'),
    recipientTypeFiat: read<String>(
      json['recipientTypeFiat'],
      'recipientTypeFiat',
    ),
    label: text('label'),
    isOwner: flag('isOwner'),
    isDefault: flag('isDefault'),
    email: text('email'),
    name: text('name'),
    securityQuestion: text('securityQuestion'),
    securityAnswer: text('securityAnswer'),
    payeeName: text('payeeName'),
    payeeCode: text('payeeCode'),
    payeeAccountNumber: text('payeeAccountNumber'),
    institutionNumber: text('institutionNumber'),
    transitNumber: text('transitNumber'),
    accountNumber: text('accountNumber'),
    defaultComment: text('defaultComment'),
    iban: text('iban'),
    isCorporate: flag('isCorporate'),
    firstname: text('firstname'),
    lastname: text('lastname'),
    corporateName: text('corporateName'),
    virtualPayeeStatus: text('virtualPayeeStatus'),
    clabe: text('clabe'),
    institutionCode: text('institutionCode'),
    phone: text('phone'),
    debitcard: text('debitcard'),
    ownerName: text('ownerName'),
    phoneNumber: text('phoneNumber'),
    claveUniform: text('claveUniform'),
    bankCode: text('bankCode'),
    accountType: text('accountType'),
    bankAccount: text('bankAccount'),
    bankName: text('bankName'),
    documentId: text('documentId'),
    documentType: text('documentType'),
  );
}

/// Throws a [BbxFormatException] naming the first invalid field.
InstitutionAccountType parseInstitutionAccountType(Map<String, dynamic> json) =>
    InstitutionAccountType(
      code: read<String>(json['code'], 'code'),
      name: read<String>(json['name'], 'name'),
      minAddressLength: read<num>(
        json['minAddressLength'],
        'minAddressLength',
      ).toInt(),
      maxAddressLength: read<num>(
        json['maxAddressLength'],
        'maxAddressLength',
      ).toInt(),
    );

/// Throws a [BbxFormatException] naming the first invalid field. The
/// account types are also read from `accounTypes`, the server's misspelt
/// key, when `accountTypes` is absent.
Institution parseInstitution(Map<String, dynamic> json) {
  final accountTypes = json.containsKey('accountTypes')
      ? json['accountTypes']
      : json['accounTypes'];
  return Institution(
    code: read<String>(json['code'], 'code'),
    name: read<String>(json['name'], 'name'),
    accountTypes: [
      for (final type in read<List<dynamic>>(accountTypes, 'accountTypes'))
        parseInstitutionAccountType(
          read<Map<String, dynamic>>(type, 'accountTypes'),
        ),
    ],
  );
}

/// Throws a [BbxFormatException] naming the first invalid field.
MyRecipient parseMyRecipient(Map<String, dynamic> json) => MyRecipient(
  recipientId: read<String>(json['recipientId'], 'recipientId'),
  userId: read<String?>(json['userId'], 'userId'),
  recipientType: read<String>(json['recipientType'], 'recipientType'),
  address: read<String?>(json['address'], 'address'),
  bitcoinAddress: read<String?>(json['bitcoinAddress'], 'bitcoinAddress'),
  lightningAddress: read<String?>(json['lightningAddress'], 'lightningAddress'),
  liquidAddress: read<String?>(json['liquidAddress'], 'liquidAddress'),
  isOwner: read<bool?>(json['isOwner'], 'isOwner'),
  isDefault: read<bool?>(json['isDefault'], 'isDefault'),
  createdAt: read<String?>(json['createdAt'], 'createdAt'),
  updatedAt: read<String?>(json['updatedAt'], 'updatedAt'),
);

/// Throws a [BbxFormatException] naming the first invalid field.
VirtualIban parseVirtualIban(Map<String, dynamic> json) => VirtualIban(
  iban: read<String?>(json['iban'], 'iban'),
  bicCode: read<String?>(json['bicCode'], 'bicCode'),
  bankAddress: read<String?>(json['bankAddress'], 'bankAddress'),
  ibanCountry: read<String?>(json['ibanCountry'], 'ibanCountry'),
);

/// Throws a [BbxFormatException] naming the first invalid field.
SepaVirtualPayee parseSepaVirtualPayee(Map<String, dynamic> json) =>
    SepaVirtualPayee(
      recipientId: read<String>(json['recipientId'], 'recipientId'),
      virtualPayeeStatus: read<String?>(
        json['virtualPayeeStatus'],
        'virtualPayeeStatus',
      ),
    );

PaymentProcessorDetails parsePaymentProcessorDetails(
  Map<String, dynamic> json,
) {
  final element =
      read<Map<String, dynamic>?>(json['element'], 'element') ?? const {};
  final extraData =
      read<Map<String, dynamic>?>(json['ppExtraData'], 'ppExtraData') ??
      const {};
  final merged = {...element, ...extraData};
  String? text(String field) {
    final value = merged[field];
    return value is num ? value.toString() : read<String?>(value, field);
  }

  return PaymentProcessorDetails(
    isEmpty: element.isEmpty && extraData.isEmpty,
    code: text('code'),
    userNbr: text('userNbr'),
    beneficiaryName: text('BENEFICIARY NAME'),
    beneficiaryEmail: text('BENEFICIARY EMAIL'),
    bankAccountDetails: text('BANK ACCOUNT DETAILS'),
    iban: text('IBAN'),
    swift: text('SWIFT'),
    institutionNumber: text('INSTITUTION NUMBER'),
    transitNumber: text('TRANSIT NUMBER'),
    accountNumber: text('ACCOUNT NUMBER'),
    routingNumber: text('ROUTING NUMBER'),
    beneficiaryAddress: text('BENEFICIARY ADDRESS'),
    bankAddress: text('BANK ADDRESS'),
    bankName: text('BANK NAME'),
    billerName: text('BILLER NAME'),
    bic: text('BIC'),
    bankAccountCountry: text('BANK ACCOUNT COUNTRY'),
    bankCountry: text('BANK COUNTRY'),
    clabe: text('CLABE'),
    cedulaJuridica: text('CÉDULA JURÍDICA'),
    cvu: text('CVU'),
    numTelefono:
        text('numTelefono') ??
        text('NUM TELEFONO') ??
        text('NUM_TELEFONO') ??
        text('PHONE NUMBER') ??
        text('phoneNumber'),
  );
}

Map<String, Object?> newFiatRecipientToJson(NewFiatRecipient recipient) => {
  'recipientTypeFiat': recipient.recipientTypeFiat,
  'label': ?recipient.label,
  'isOwner': ?recipient.isOwner,
  'isDefault': ?recipient.isDefault,
  'isArchived': recipient.isArchived,
  for (final MapEntry(:key, :value) in _newFiatRecipientFields(
    recipient,
  ).entries)
    key: ?value,
};

/// The holder fields of a Colombian recipient: `name` and `lastname` for a
/// person, `corporateName` for a company, and always `isCorporate`.
Map<String, Object?> _copHolderFields(NewCopHolder holder) => switch (holder) {
  NewCopIndividual(:final name, :final lastname) => {
    'isCorporate': false,
    'name': name,
    'lastname': lastname,
  },
  NewCopCorporate(:final corporateName) => {
    'isCorporate': true,
    'corporateName': corporateName,
  },
};

Map<String, Object?> _newFiatRecipientFields(NewFiatRecipient recipient) =>
    switch (recipient) {
      NewInteracEmailCadRecipient() => {
        'email': recipient.email,
        'name': recipient.name,
        'securityQuestion': recipient.securityQuestion,
        'securityAnswer': recipient.securityAnswer,
      },
      NewBillPaymentCadRecipient() => {
        'payeeName': recipient.payeeName,
        'payeeCode': recipient.payeeCode,
        'payeeAccountNumber': recipient.payeeAccountNumber,
      },
      NewBankTransferCadRecipient() => {
        'name': recipient.name,
        'institutionNumber': recipient.institutionNumber,
        'transitNumber': recipient.transitNumber,
        'accountNumber': recipient.accountNumber,
        'defaultComment': recipient.defaultComment,
      },
      NewSepaEurRecipient() => {
        'iban': recipient.iban,
        'isCorporate': recipient.isCorporate,
        'firstname': recipient.firstname,
        'lastname': recipient.lastname,
        'corporateName': recipient.corporateName,
      },
      NewSpeiClabeMxnRecipient() => {
        'name': recipient.name,
        'clabe': recipient.clabe,
      },
      NewSpeiSmsMxnRecipient() => {
        'name': recipient.name,
        'institutionCode': recipient.institutionCode,
        'phone': recipient.phone,
      },
      NewSpeiCardMxnRecipient() => {
        'name': recipient.name,
        'institutionCode': recipient.institutionCode,
        'debitcard': recipient.debitcard,
      },
      NewSinpeIbanUsdRecipient() => {
        'iban': recipient.iban,
        'ownerName': recipient.ownerName,
      },
      NewSinpeIbanCrcRecipient() => {
        'iban': recipient.iban,
        'ownerName': recipient.ownerName,
      },
      NewSinpeMovilCrcRecipient() => {
        'ownerName': recipient.ownerName,
        'phoneNumber': recipient.phoneNumber,
      },
      NewBankTransferArsRecipient() => {
        'name': recipient.name,
        'claveUniform': recipient.claveUniform,
      },
      NewPseColombiaCopRecipient() => {
        ..._copHolderFields(recipient.holder),
        'email': recipient.email,
        'bankCode': recipient.bankCode,
        'accountType': recipient.accountType,
        'bankAccount': recipient.bankAccount,
        'documentId': recipient.documentId,
        'documentType': recipient.documentType,
      },
      NewNequiColombiaCopRecipient() => {
        ..._copHolderFields(recipient.holder),
        'email': recipient.email,
        'bankAccount': recipient.bankAccount,
        'documentId': recipient.documentId,
        'documentType': recipient.documentType,
      },
    };
