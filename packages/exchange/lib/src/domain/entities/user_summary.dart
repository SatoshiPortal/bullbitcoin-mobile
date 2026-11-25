import 'package:freezed_annotation/freezed_annotation.dart';

import '../catalog/kyc_policy.dart';
import 'btc_network.dart';
import 'dca.dart';
import 'order.dart';

part 'user_summary.freezed.dart';

/// Status of KYC document uploads
enum KycDocumentStatus {
  notUploaded('NOT_UPLOADED'),
  underReview('UNDER_REVIEW'),
  accepted('ACCEPTED'),
  rejected('REJECTED'),

  /// A status this build doesn't know. Not read as "not uploaded", so the app
  /// never offers an upload the exchange may not expect.
  unknown('UNKNOWN');

  final String value;

  const KycDocumentStatus(this.value);

  bool get isNotUploaded => this == KycDocumentStatus.notUploaded;
  bool get isUnderReview => this == KycDocumentStatus.underReview;
  bool get isAccepted => this == KycDocumentStatus.accepted;
  bool get isRejected => this == KycDocumentStatus.rejected;

  /// Whether the review is over (accepted or rejected).
  bool get isTerminal => switch (this) {
    KycDocumentStatus.accepted || KycDocumentStatus.rejected => true,
    KycDocumentStatus.notUploaded ||
    KycDocumentStatus.underReview ||
    KycDocumentStatus.unknown => false,
  };

  /// A document review has no failed status; a refused one is [rejected].
  bool get isFailed => false;
}

/// KYC documents status for ID, proof of residence, and selfie
@freezed
sealed class UserKycDocuments with _$UserKycDocuments {
  const factory UserKycDocuments({
    required KycDocumentStatus id,
    required KycDocumentStatus proofOfResidence,
    required KycDocumentStatus selfie,
  }) = _UserKycDocuments;
}

/// Overall KYC document status including secure file upload
@freezed
sealed class UserKycDocumentStatus with _$UserKycDocumentStatus {
  const factory UserKycDocumentStatus({
    required KycDocumentStatus secureFileUpload,
    required UserKycDocuments documents,
  }) = _UserKycDocumentStatus;
}

enum ExchangeLanguage {
  en('EN'),
  fr('FR'),
  es('ES'),
  it('IT');

  const ExchangeLanguage(this._lang);
  final String _lang;

  String get code => _lang;

  String get displayName {
    switch (this) {
      case ExchangeLanguage.en:
        return 'English';
      case ExchangeLanguage.fr:
        return 'French';
      case ExchangeLanguage.es:
        return 'Spanish';
      case ExchangeLanguage.it:
        return 'Italian';
    }
  }
}

@freezed
sealed class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String firstName,
    required String lastName,
  }) = _UserProfile;
}

@freezed
sealed class UserBalance with _$UserBalance {
  const factory UserBalance({
    required double amount,
    required String currencyCode,
  }) = _UserBalance;
}

@freezed
sealed class UserDca with _$UserDca {
  const factory UserDca({
    required bool isActive,
    DcaBuyFrequency? frequency,
    double? amount,
    FiatCurrency? currency,
    BtcNetwork? network,
    String? address,
  }) = _UserDca;
}

@freezed
sealed class UserAutoBuyAddresses with _$UserAutoBuyAddresses {
  const factory UserAutoBuyAddresses({
    String? bitcoin,
    String? lightning,
    String? liquid,
  }) = _UserAutoBuyAddresses;
}

@freezed
sealed class UserAutoBuy with _$UserAutoBuy {
  const factory UserAutoBuy({
    required bool isActive,
    required UserAutoBuyAddresses addresses,
  }) = _UserAutoBuy;
}

@freezed
sealed class UserSummary with _$UserSummary {
  const factory UserSummary({
    required int userNumber,
    String? userId,
    required List<String> groups,
    required UserProfile profile,
    required String email,
    required List<UserBalance> balances,
    String? language,
    String? currency,
    required UserDca dca,
    required UserAutoBuy autoBuy,
    @Default(true) bool emailNotificationsEnabled,
    // Whether this account may payjoin with the exchange — the buy payout and
    // the sell payin alike. Server-gated: the backend derives it from the
    // account's pilot group, so we read the published flag rather than
    // re-deriving it from [groups] (a backend-internal detail).
    //
    // Fail closed: an older backend, a partial response, or a stripped field
    // must disable payjoin rather than offer the user a payjoin the exchange
    // would then reject.
    @Default(false) bool payjoinReceiveEnabled,
    UserKycDocumentStatus? kycDocumentStatus,
  }) = _UserSummary;

  const UserSummary._();

  /// The account's KYC groups. Which markets they allow, and up to what
  /// amount, is the market's [KycPolicy].
  Set<KycGroup> get kycGroups => KycGroup.fromServerGroups(groups);

  bool get isFullyVerifiedKycLevel =>
      groups.contains(KycGroup.identityVerified.serverName);
  bool get isLightKycLevel => groups.contains(KycGroup.canadaLight.serverName);
  bool get isLimitedKycLevel => groups.contains(KycGroup.limited.serverName);
  bool get isCorporate => groups.contains('KYC_IS_CORPORATE');
  bool get isEuropeanJurisdiction => groups.contains('JURI_EU');
  bool get isEligibleForConfidentialSepa =>
      isFullyVerifiedKycLevel && !isCorporate && isEuropeanJurisdiction;
  bool get hasConsentedScamWarning => groups.contains('CONSENT_SCAM_WARNING');

  static const _fundingRestrictedGroups = {
    'RESTRICTED_FULL',
    'RISK_PROHIBITED_COUNTRY',
  };

  bool get isFundingRestricted => groups.any(_fundingRestrictedGroups.contains);
}
