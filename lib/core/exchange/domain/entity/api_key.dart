class ExchangeApiKey {
  final String id;
  final String key;
  final String name;
  final String userId;

  const ExchangeApiKey({
    required this.id,
    required this.key,
    required this.name,
    required this.userId,
  });

  ExchangeApiKey copyWith({
    String? id,
    String? key,
    String? name,
    String? userId,
  }) {
    return ExchangeApiKey(
      id: id ?? this.id,
      key: key ?? this.key,
      name: name ?? this.name,
      userId: userId ?? this.userId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ExchangeApiKey &&
        other.id == id &&
        other.key == key &&
        other.name == name &&
        other.userId == userId;
  }

  @override
  int get hashCode =>
      id.hashCode ^ key.hashCode ^ name.hashCode ^ userId.hashCode;

  @override
  String toString() {
    return 'ExchangeApiKey(id: $id, name: $name, userId: $userId)';
  }
}
