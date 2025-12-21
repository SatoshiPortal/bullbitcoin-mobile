class UserPreferencePayloadModel {
  final String? language;
  final String? currencyCode;
  final String? dcaEnabled;
  final String? autoBuyEnabled;
  final bool? emailNotificationsEnabled;

  UserPreferencePayloadModel({
    this.language,
    this.currencyCode,
    this.dcaEnabled,
    this.autoBuyEnabled,
    this.emailNotificationsEnabled,
  });

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {};

    data['LANGUAGE'] = language;
    data['DEFAULT_FIAT_CURRENCY_CODE'] = currencyCode;
    if (dcaEnabled != null) {
      data['DCA_ENABLED'] = dcaEnabled;
    }
    if (autoBuyEnabled != null) {
      data['AUTO_BUY_ENABLED'] = autoBuyEnabled;
    }
    if (emailNotificationsEnabled != null) {
      data['EMAIL_NOTIFICATIONS_ENABLED'] = emailNotificationsEnabled;
    }

    data.removeWhere((key, value) => value == null);
    return data;
  }
}
