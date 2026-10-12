enum VerificationLevel { identityVerified, light, limited, notVerified }

final class AccountInfo {
  final int userNumber;
  final String email;
  final String firstName;
  final String lastName;
  final VerificationLevel verificationLevel;

  const AccountInfo({
    required this.userNumber,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.verificationLevel,
  });
}
