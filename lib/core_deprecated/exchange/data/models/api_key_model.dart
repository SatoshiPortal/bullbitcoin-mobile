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
      lastUsedAt:
          json['lastUsedAt'] != null
              ? (json['lastUsedAt'] is String
                  ? DateTime.parse(
                    json['lastUsedAt'] as String,
                  ).millisecondsSinceEpoch
                  : json['lastUsedAt'] as int)
              : null,
      createdAt:
          json['createdAt'] is String
              ? DateTime.parse(
                json['createdAt'] as String,
              ).millisecondsSinceEpoch
              : json['createdAt'] as int,
      updatedAt:
          json['updatedAt'] is String
              ? DateTime.parse(
                json['updatedAt'] as String,
              ).millisecondsSinceEpoch
              : json['updatedAt'] as int,
      expiresAt:
          json['expiresAt'] != null
              ? (json['expiresAt'] is String
                  ? DateTime.parse(
                    json['expiresAt'] as String,
                  ).millisecondsSinceEpoch
                  : json['expiresAt'] as int)
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
      apiKey: ExchangeApiKeyModel.fromJson(
        json['apiKey'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'apiKey': apiKey.toJson()};
  }
}
