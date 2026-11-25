import 'package:meta/meta.dart';

import 'entities/user_summary.dart';

/// The account preferences a caller wants changed. A null field is left as
/// the account has it now.
@immutable
final class ExchangePreferencesPatch {
  final String? language;
  final String? currency;
  final bool? dcaEnabled;
  final bool? autoBuyEnabled;
  final bool? emailNotificationsEnabled;

  const ExchangePreferencesPatch({
    this.language,
    this.currency,
    this.dcaEnabled,
    this.autoBuyEnabled,
    this.emailNotificationsEnabled,
  });

  /// The part of this patch that differs from [summary]; empty when the
  /// account already has every requested value.
  ExchangePreferencesPatch changesFrom(UserSummary summary) =>
      ExchangePreferencesPatch(
        language: language == summary.language ? null : language,
        currency: currency == summary.currency ? null : currency,
        dcaEnabled: dcaEnabled == summary.dca.isActive ? null : dcaEnabled,
        autoBuyEnabled: autoBuyEnabled == summary.autoBuy.isActive
            ? null
            : autoBuyEnabled,
        emailNotificationsEnabled:
            emailNotificationsEnabled == summary.emailNotificationsEnabled
            ? null
            : emailNotificationsEnabled,
      );

  bool get isEmpty =>
      language == null &&
      currency == null &&
      dcaEnabled == null &&
      autoBuyEnabled == null &&
      emailNotificationsEnabled == null;

  @override
  bool operator ==(Object other) =>
      other is ExchangePreferencesPatch &&
      other.language == language &&
      other.currency == currency &&
      other.dcaEnabled == dcaEnabled &&
      other.autoBuyEnabled == autoBuyEnabled &&
      other.emailNotificationsEnabled == emailNotificationsEnabled;

  @override
  int get hashCode => Object.hash(
    language,
    currency,
    dcaEnabled,
    autoBuyEnabled,
    emailNotificationsEnabled,
  );

  @override
  String toString() =>
      'ExchangePreferencesPatch(${[if (language != null) 'language', if (currency != null) 'currency', if (dcaEnabled != null) 'dcaEnabled', if (autoBuyEnabled != null) 'autoBuyEnabled', if (emailNotificationsEnabled != null) 'emailNotificationsEnabled'].join(', ')})';
}
