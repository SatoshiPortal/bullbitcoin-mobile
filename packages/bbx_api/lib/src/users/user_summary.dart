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
}

@immutable
class UserProfile {
  final String firstName;
  final String lastName;

  const UserProfile({required this.firstName, required this.lastName});
}

@immutable
class UserBalance {
  final double amount;
  final String currencyCode;

  const UserBalance({required this.amount, required this.currencyCode});
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
}

@immutable
class UserAutoBuy {
  final bool isActive;
  final UserAutoBuyAddresses addresses;

  const UserAutoBuy({required this.isActive, required this.addresses});
}

@immutable
class UserAutoBuyAddresses {
  final String? bitcoin;
  final String? lightning;
  final String? liquid;

  const UserAutoBuyAddresses({this.bitcoin, this.lightning, this.liquid});
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
}
