import 'package:meta/meta.dart';

/// The legal name on the user's exchange account.
@immutable
class AccountOwnerName {
  final String firstName;
  final String lastName;

  const AccountOwnerName({required this.firstName, required this.lastName});

  String get fullName => '$firstName $lastName'.trim();

  @override
  bool operator ==(Object other) =>
      other is AccountOwnerName &&
      other.firstName == firstName &&
      other.lastName == lastName;

  @override
  int get hashCode => Object.hash(firstName, lastName);
}
