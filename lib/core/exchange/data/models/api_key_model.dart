// Simple version without freezed for easier implementation if desired
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

  factory ExchangeApiKeyModel.fromJson(Map<String, dynamic> json) {
    return ExchangeApiKeyModel(
      id: json['id'] as String,
      key: json['key'] as String,
      name: json['name'] as String,
      userId: json['userId'] as String,
      isActive: json['isActive'] as bool,
      // Convert ISO8601 string dates to millisecond timestamps
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String).millisecondsSinceEpoch
          : null,
      createdAt:
          DateTime.parse(json['createdAt'] as String).millisecondsSinceEpoch,
      updatedAt:
          DateTime.parse(json['updatedAt'] as String).millisecondsSinceEpoch,
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String).millisecondsSinceEpoch
          : null,
    );
  }

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

class ExchangeApiKeyModelResponse {
  final ExchangeApiKeyModel apiKey;

  ExchangeApiKeyModelResponse({required this.apiKey});

  factory ExchangeApiKeyModelResponse.fromJson(Map<String, dynamic> json) {
    return ExchangeApiKeyModelResponse(
      apiKey:
          ExchangeApiKeyModel.fromJson(json['apiKey'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey.toJson(),
    };
  }
}
