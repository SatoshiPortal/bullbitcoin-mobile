import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/users/user_preferences.dart';
import 'package:bbx_api/src/users/user_summary.dart';

UserSummary parseUserSummary(Map<String, dynamic> json) {
  final kyc = read<Map<String, dynamic>?>(
    json['kycDocumentStatus'],
    'kycDocumentStatus',
  );
  return UserSummary(
    userNumber: read<num>(json['userNumber'], 'userNumber').toInt(),
    userId: read<String?>(json['userId'], 'userId'),
    groups: [
      for (final group in read<List<dynamic>>(json['groups'], 'groups'))
        read<String>(group, 'groups'),
    ],
    profile: parseUserProfile(
      read<Map<String, dynamic>>(json['profile'], 'profile'),
    ),
    email: read<String>(json['email'], 'email'),
    balances: [
      for (final balance in read<List<dynamic>>(json['balances'], 'balances'))
        parseUserBalance(read<Map<String, dynamic>>(balance, 'balances')),
    ],
    language: read<String?>(json['language'], 'language'),
    currency: read<String?>(json['currency'], 'currency'),
    dca: parseUserDca(read<Map<String, dynamic>>(json['dca'], 'dca')),
    autoBuy: parseUserAutoBuy(
      read<Map<String, dynamic>>(json['autoBuy'], 'autoBuy'),
    ),
    emailNotificationsEnabled:
        read<bool?>(
          json['emailNotificationsEnabled'],
          'emailNotificationsEnabled',
        ) ??
        true,
    payjoinReceiveEnabled:
        read<bool?>(json['payjoinReceiveEnabled'], 'payjoinReceiveEnabled') ??
        false,
    kycDocumentStatus: kyc == null ? null : parseUserKycDocumentStatus(kyc),
  );
}

UserProfile parseUserProfile(Map<String, dynamic> json) => UserProfile(
  firstName: read<String>(json['firstName'], 'firstName'),
  lastName: read<String>(json['lastName'], 'lastName'),
);

UserBalance parseUserBalance(Map<String, dynamic> json) => UserBalance(
  amount: read<num>(json['amount'], 'amount').toDouble(),
  currencyCode: read<String>(json['currencyCode'], 'currencyCode'),
);

UserDca parseUserDca(Map<String, dynamic> json) => UserDca(
  isActive: read<bool>(json['isActive'], 'isActive'),
  frequency: read<String?>(json['frequency'], 'frequency'),
  amount: read<num?>(json['amount'], 'amount')?.toDouble(),
  address: read<String?>(json['address'], 'address'),
  recipientType: read<String?>(json['recipientType'], 'recipientType'),
  currencyCode: read<String?>(json['currencyCode'], 'currencyCode'),
);

UserAutoBuy parseUserAutoBuy(Map<String, dynamic> json) => UserAutoBuy(
  isActive: read<bool>(json['isActive'], 'isActive'),
  addresses: parseUserAutoBuyAddresses(
    read<Map<String, dynamic>>(json['addresses'], 'addresses'),
  ),
);

UserAutoBuyAddresses parseUserAutoBuyAddresses(Map<String, dynamic> json) =>
    UserAutoBuyAddresses(
      bitcoin: read<String?>(json['bitcoin'], 'bitcoin'),
      lightning: read<String?>(json['lightning'], 'lightning'),
      liquid: read<String?>(json['liquid'], 'liquid'),
    );

UserKycDocumentStatus parseUserKycDocumentStatus(Map<String, dynamic> json) =>
    UserKycDocumentStatus(
      secureFileUpload:
          read<String?>(json['secureFileUpload'], 'secureFileUpload') ??
          UserKycDocumentStatus.notUploaded,
      documents: parseUserKycDocuments(
        read<Map<String, dynamic>>(json['documents'], 'documents'),
      ),
    );

UserKycDocuments parseUserKycDocuments(Map<String, dynamic> json) {
  String status(String field) =>
      read<String?>(json[field], field) ?? UserKycDocumentStatus.notUploaded;
  return UserKycDocuments(
    id: status('id'),
    proofOfResidence: status('proofOfResidence'),
    selfie: status('selfie'),
  );
}

Map<String, String> userPreferencesToJson(UserPreferences preferences) => {
  'LANGUAGE': ?preferences.language,
  'DEFAULT_FIAT_CURRENCY_CODE': ?preferences.defaultFiatCurrencyCode,
  'DCA_ENABLED': ?preferences.dcaEnabled,
  'AUTO_BUY_ENABLED': ?preferences.autoBuyEnabled,
  'EMAIL_NOTIFICATIONS': ?preferences.emailNotifications,
};
