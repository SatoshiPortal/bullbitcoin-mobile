import 'dart:convert';

class ExchangeApiKeyModel {
  final String id;
  final String key;
  final String name;
  final String userId;
  final bool isActive;
  final int? lastUsedAt;
  final int createdAt;
  final int updatedAt;
  final int? expiresAt;

  ExchangeApiKeyModel({
    required this.id,
    required this.key,
    required this.name,
    required this.userId,
    required this.isActive,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
  });

  /// Accepts the existing auth envelopes and the WebView's JSON string layers.
  /// Malformed input is data, not a TypeError or an exception containing secrets.
  static ExchangeApiKeyModel? tryFromAuthResponse(Object? response) {
    response = _decodeAuthResponse(response);
    if (response is! Map<String, dynamic> || response['error'] != null) {
      return null;
    }
    final Map<String, dynamic> payload;
    if (response['apiKey'] case final Map<String, dynamic> value) {
      payload = value;
    } else if (response['result'] case {
      'apiKey': final Map<String, dynamic> value,
    }) {
      payload = value;
    } else if (response['data'] case {
      'apiKey': final Map<String, dynamic> value,
    }) {
      payload = value;
    } else {
      payload = response;
    }
    if (payload case {
      'id': final String id,
      'key': final String key,
      'name': final String name,
      'userId': final String userId,
      'isActive': final bool isActive,
      'createdAt': final Object created,
      'updatedAt': final Object updated,
    }) {
      final createdAt = _timestamp(created);
      final updatedAt = _timestamp(updated);
      final lastUsedAt = _timestamp(payload['lastUsedAt']);
      final expiresAt = _timestamp(payload['expiresAt']);
      if (createdAt == null ||
          updatedAt == null ||
          (payload['lastUsedAt'] != null && lastUsedAt == null) ||
          (payload['expiresAt'] != null && expiresAt == null)) {
        return null;
      }
      return ExchangeApiKeyModel(
        id: id,
        key: key,
        name: name,
        userId: userId,
        isActive: isActive,
        createdAt: createdAt,
        updatedAt: updatedAt,
        lastUsedAt: lastUsedAt,
        expiresAt: expiresAt,
      );
    }
    return null;
  }

  /// An unfinished/rejected web request keeps the existing WebView flow open.
  static bool isAuthenticationDeferred(Object? response) {
    final decoded = _decodeAuthResponse(response);
    return decoded is Map<String, dynamic> && decoded['error'] != null;
  }

  static Object? _decodeAuthResponse(Object? response) {
    try {
      for (var layer = 0; layer < 2 && response is String; layer++) {
        response = jsonDecode(response);
      }
    } on FormatException {
      return null;
    }
    return response;
  }

  static int? _timestamp(Object? value) => switch (value) {
    final int timestamp => timestamp,
    final String timestamp => DateTime.tryParse(
      timestamp,
    )?.millisecondsSinceEpoch,
    _ => null,
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': key,
      'name': name,
      'userId': userId,
      'isActive': isActive,
      'lastUsedAt': lastUsedAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'expiresAt': expiresAt,
    };
  }
}
