final class ExchangeAccount {
  final int userNumber;
  final String firstName;
  final String lastName;
  final String email;
  final String? language;
  final String? currency;
  final bool emailNotificationsEnabled;
  final bool isFullyVerifiedKycLevel;
  final bool isLightKycLevel;
  final bool isLimitedKycLevel;
  final bool isFundingRestricted;
  final bool hasConsentedScamWarning;
  final bool payjoinReceiveEnabled;

  const ExchangeAccount({
    required this.userNumber,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.language,
    required this.currency,
    required this.emailNotificationsEnabled,
    required this.isFullyVerifiedKycLevel,
    required this.isLightKycLevel,
    required this.isLimitedKycLevel,
    required this.isFundingRestricted,
    required this.hasConsentedScamWarning,
    required this.payjoinReceiveEnabled,
  });
}
