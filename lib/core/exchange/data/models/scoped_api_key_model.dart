/// The scoped `SELL_TO_FIAT_BALANCE` Bull Bitcoin credential, persisted bound to
/// the Bull Bitcoin `userId` of the ordinary key it was delivered with.
///
/// The binding lets the credential lifecycle tell a same-user re-login (preserve
/// or replace) apart from an account switch (remove before completing the
/// switch). The plaintext [key] must never leave the secure data layer as
/// anything other than a value passed into the final Bullnym transport call.
class ScopedApiKeyModel {
  /// Matches `bbak-` followed by exactly 64 lowercase hexadecimal characters.
  static final RegExp format = RegExp(r'^bbak-[0-9a-f]{64}$');

  final String userId;
  final String key;

  const ScopedApiKeyModel({required this.userId, required this.key});

  /// Returns true when [key] is a well-formed scoped credential value.
  bool get isWellFormed => format.hasMatch(key);

  factory ScopedApiKeyModel.fromJson(Map<String, dynamic> json) {
    return ScopedApiKeyModel(
      userId: json['userId'] as String,
      key: json['key'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'userId': userId, 'key': key};
}
