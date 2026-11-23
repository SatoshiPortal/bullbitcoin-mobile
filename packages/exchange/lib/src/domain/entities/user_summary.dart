import 'package:freezed_annotation/freezed_annotation.dart';

import 'dca.dart';
import 'order.dart';

part 'user_summary.freezed.dart';

/// Status of KYC document uploads
enum KycDocumentStatus {
  notUploaded,
  underReview,
  accepted,
  rejected;

  bool get isNotUploaded => this == KycDocumentStatus.notUploaded;
  bool get isUnderReview => this == KycDocumentStatus.underReview;
  bool get isAccepted => this == KycDocumentStatus.accepted;
  bool get isRejected => this == KycDocumentStatus.rejected;
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
    DcaNetwork? network,
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

  bool get isFullyVerifiedKycLevel => groups.contains('KYC_IDENTITY_VERIFIED');
  bool get isLightKycLevel => groups.contains('KYC_CANADA_LIGHT_VERIFICATION');
  bool get isLimitedKycLevel => groups.contains('KYC_LIMITED_VERIFICATION');
  bool get isSinpeVerified => groups.contains('KYC_SINPE_VERIFIED');
  bool get isMissionary => groups.contains('MISSIONARY');
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

  static const _limitedKycCurrencies = {
    FiatCurrency.cad,
    FiatCurrency.crc,
    FiatCurrency.ars,
  };

  /// Maximum CAD amount per transaction for Limited Identity Verification
  /// users, from the server's published limits table
  /// (`getTradingLimitAndVerificationsPerCountry` in API-Orders). The server
  /// also caps them at 3000 CAD per day; the app has no daily volume, so that
  /// cap is left to the server.
  static const _cadLimitedKycMaxAmount = 999.99;

  /// Whether the user's KYC level permits transactions in [currency], per the
  /// server's limits table: Canada light verification trades CAD; limited
  /// verification trades CAD, CRC and ARS (not available elsewhere); SINPE
  /// verified trades CRC; missionary trades ARS.
  bool isKycOk(FiatCurrency currency) {
    if (isFullyVerifiedKycLevel) return true;
    if (isLightKycLevel && currency == FiatCurrency.cad) return true;
    if (isLimitedKycLevel && _limitedKycCurrencies.contains(currency)) {
      return true;
    }
    if (isSinpeVerified && currency == FiatCurrency.crc) return true;
    if (isMissionary && currency == FiatCurrency.ars) return true;
    return false;
  }

  /// Whether [amount] exceeds the per-transaction limit for the user's KYC
  /// level in [currency]. Only limited verification in CAD has one (999.99);
  /// Canada light verification has no cap. The daily caps (CAD, CRC, ARS) need
  /// the user's daily volume, which the app does not have, so the server
  /// enforces them.
  bool isAmountExceeded(double amount, FiatCurrency currency) {
    if (isFullyVerifiedKycLevel || currency != FiatCurrency.cad) return false;
    if (isLightKycLevel) return false;
    return isLimitedKycLevel && amount > _cadLimitedKycMaxAmount;
  }

  /// Returns true when the user needs to upgrade KYC to proceed.
  bool needsKycUpgrade(double amount, FiatCurrency currency) {
    return !isKycOk(currency) || isAmountExceeded(amount, currency);
  }
}
