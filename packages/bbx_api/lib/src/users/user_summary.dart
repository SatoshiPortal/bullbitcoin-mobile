import 'package:bbx_api/src/json.dart';
import 'package:meta/meta.dart';

/// The result of `getUserSummary`.
@immutable
class UserSummary {
  final int userNumber;
  final String? userId;
  final List<String> groups;
  final UserProfile profile;
  final String email;
  final List<UserBalance> balances;
  final String? language;
  final String? currency;
  final UserDca dca;
  final UserAutoBuy autoBuy;

  /// `true` when the server omits it.
  final bool emailNotificationsEnabled;

  /// `false` when the server omits it.
  final bool payjoinReceiveEnabled;
  final UserKycDocumentStatus? kycDocumentStatus;

  const UserSummary({
    required this.userNumber,
    this.userId,
    required this.groups,
    required this.profile,
    required this.email,
    required this.balances,
    this.language,
    this.currency,
    required this.dca,
    required this.autoBuy,
    this.emailNotificationsEnabled = true,
    this.payjoinReceiveEnabled = false,
    this.kycDocumentStatus,
  });

  factory UserSummary.fromJson(Map<String, dynamic> json) {
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
      profile: UserProfile.fromJson(
        read<Map<String, dynamic>>(json['profile'], 'profile'),
      ),
      email: read<String>(json['email'], 'email'),
      balances: [
        for (final balance in read<List<dynamic>>(json['balances'], 'balances'))
          UserBalance.fromJson(read<Map<String, dynamic>>(balance, 'balances')),
      ],
      language: read<String?>(json['language'], 'language'),
      currency: read<String?>(json['currency'], 'currency'),
      dca: UserDca.fromJson(read<Map<String, dynamic>>(json['dca'], 'dca')),
      autoBuy: UserAutoBuy.fromJson(
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
      kycDocumentStatus: kyc == null
          ? null
          : UserKycDocumentStatus.fromJson(kyc),
    );
  }
}

@immutable
class UserProfile {
  final String firstName;
  final String lastName;

  const UserProfile({required this.firstName, required this.lastName});

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    firstName: read<String>(json['firstName'], 'firstName'),
    lastName: read<String>(json['lastName'], 'lastName'),
  );
}

@immutable
class UserBalance {
  final double amount;
  final String currencyCode;

  const UserBalance({required this.amount, required this.currencyCode});

  factory UserBalance.fromJson(Map<String, dynamic> json) => UserBalance(
    amount: read<num>(json['amount'], 'amount').toDouble(),
    currencyCode: read<String>(json['currencyCode'], 'currencyCode'),
  );
}

/// The recurring buy settings, with the server's raw codes.
@immutable
class UserDca {
  final bool isActive;

  /// For example `daily`; the server's spelling, not normalised.
  final String? frequency;
  final double? amount;
  final String? address;

  /// For example `OUT_BITCOIN_ADDRESS`.
  final String? recipientType;
  final String? currencyCode;

  const UserDca({
    required this.isActive,
    this.frequency,
    this.amount,
    this.address,
    this.recipientType,
    this.currencyCode,
  });

  factory UserDca.fromJson(Map<String, dynamic> json) => UserDca(
    isActive: read<bool>(json['isActive'], 'isActive'),
    frequency: read<String?>(json['frequency'], 'frequency'),
    amount: read<num?>(json['amount'], 'amount')?.toDouble(),
    address: read<String?>(json['address'], 'address'),
    recipientType: read<String?>(json['recipientType'], 'recipientType'),
    currencyCode: read<String?>(json['currencyCode'], 'currencyCode'),
  );
}

@immutable
class UserAutoBuy {
  final bool isActive;
  final UserAutoBuyAddresses addresses;

  const UserAutoBuy({required this.isActive, required this.addresses});

  factory UserAutoBuy.fromJson(Map<String, dynamic> json) => UserAutoBuy(
    isActive: read<bool>(json['isActive'], 'isActive'),
    addresses: UserAutoBuyAddresses.fromJson(
      read<Map<String, dynamic>>(json['addresses'], 'addresses'),
    ),
  );
}

@immutable
class UserAutoBuyAddresses {
  final String? bitcoin;
  final String? lightning;
  final String? liquid;

  const UserAutoBuyAddresses({this.bitcoin, this.lightning, this.liquid});

  factory UserAutoBuyAddresses.fromJson(Map<String, dynamic> json) =>
      UserAutoBuyAddresses(
        bitcoin: read<String?>(json['bitcoin'], 'bitcoin'),
        lightning: read<String?>(json['lightning'], 'lightning'),
        liquid: read<String?>(json['liquid'], 'liquid'),
      );
}

/// KYC document statuses as the server's codes (`ACCEPTED`, `UNDER_REVIEW`,
/// `REJECTED`, `NOT_UPLOADED`); a missing status is `NOT_UPLOADED`.
@immutable
class UserKycDocumentStatus {
  static const notUploaded = 'NOT_UPLOADED';

  final String secureFileUpload;
  final UserKycDocuments documents;

  const UserKycDocumentStatus({
    required this.secureFileUpload,
    required this.documents,
  });

  factory UserKycDocumentStatus.fromJson(Map<String, dynamic> json) =>
      UserKycDocumentStatus(
        secureFileUpload:
            read<String?>(json['secureFileUpload'], 'secureFileUpload') ??
            notUploaded,
        documents: UserKycDocuments.fromJson(
          read<Map<String, dynamic>>(json['documents'], 'documents'),
        ),
      );
}

@immutable
class UserKycDocuments {
  final String id;
  final String proofOfResidence;
  final String selfie;

  const UserKycDocuments({
    required this.id,
    required this.proofOfResidence,
    required this.selfie,
  });

  factory UserKycDocuments.fromJson(Map<String, dynamic> json) {
    String status(String field) =>
        read<String?>(json[field], field) ?? UserKycDocumentStatus.notUploaded;
    return UserKycDocuments(
      id: status('id'),
      proofOfResidence: status('proofOfResidence'),
      selfie: status('selfie'),
    );
  }
}
