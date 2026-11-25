import 'package:bbx_api/src/json.dart';
import 'package:bbx_api/src/users/user_preferences.dart';
import 'package:bbx_api/src/users/user_summary.dart';

/// Tolerant where a default is harmless: a missing or unreadable profile,
/// auto-buy address set or KYC document set reads as empty, so one bad
/// display field doesn't make the whole account unreadable. The fields a
/// default would change a decision on stay required: `userNumber`, `groups`
/// (KYC), `email`, `balances`, and `isActive` of `dca` and `autoBuy`.
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
    profile: parseUserProfile(_optionalObject(json['profile'])),
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

/// A missing or non-text name is empty.
UserProfile parseUserProfile(Map<String, dynamic> json) => UserProfile(
  firstName: _optionalText(json['firstName']),
  lastName: _optionalText(json['lastName']),
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
  addresses: parseUserAutoBuyAddresses(_optionalObject(json['addresses'])),
);

/// An address that is not text is absent.
UserAutoBuyAddresses parseUserAutoBuyAddresses(Map<String, dynamic> json) =>
    UserAutoBuyAddresses(
      bitcoin: _textOrNull(json['bitcoin']),
      lightning: _textOrNull(json['lightning']),
      liquid: _textOrNull(json['liquid']),
    );

UserKycDocumentStatus parseUserKycDocumentStatus(Map<String, dynamic> json) =>
    UserKycDocumentStatus(
      secureFileUpload:
          read<String?>(json['secureFileUpload'], 'secureFileUpload') ??
          UserKycDocumentStatus.notUploaded,
      documents: parseUserKycDocuments(_optionalObject(json['documents'])),
    );

UserKycDocuments parseUserKycDocuments(Map<String, dynamic> json) {
  String status(String field) =>
      _textOrNull(json[field]) ?? UserKycDocumentStatus.notUploaded;
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

/// [value] when it is an object, otherwise an empty one.
Map<String, dynamic> _optionalObject(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

String? _textOrNull(Object? value) => value is String ? value : null;

String _optionalText(Object? value) => _textOrNull(value) ?? '';
