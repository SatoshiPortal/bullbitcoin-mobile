/// Wire model for `GET /api/v1/mining/blocks/timestamp/:unixSeconds` (a
/// mempool/Esplora-style server). Pure serialization: field presence/type
/// checks only — no business rule (that lives in
/// `WalletBirthdayCheckpoint`'s own invariants and in the repository's
/// "not later than requested" retry policy).
///
/// Example body: `{"height":0,"hash":"000000000019d6...","timestamp":`
/// `"2009-01-03T18:15:05.000Z"}`.
class WalletBirthdayCheckpointResponseModel {
  final int height;
  final String hash;
  final DateTime timestamp;

  const WalletBirthdayCheckpointResponseModel({
    required this.height,
    required this.hash,
    required this.timestamp,
  });

  /// Throws [FormatException] if a required field is missing or the wrong
  /// shape. Never throws for a value that merely looks implausible (e.g. a
  /// negative height, a short hash) — that is
  /// [WalletBirthdayCheckpoint]'s own invariant to enforce.
  factory WalletBirthdayCheckpointResponseModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final height = json['height'];
    final hash = json['hash'];
    final timestamp = json['timestamp'];

    if (height is! int) {
      throw FormatException(
        'Missing or non-integer "height" field',
        json,
      );
    }
    if (hash is! String || hash.isEmpty) {
      throw FormatException('Missing or empty "hash" field', json);
    }
    if (timestamp is! String) {
      throw FormatException('Missing or non-string "timestamp" field', json);
    }

    final parsedTimestamp = DateTime.tryParse(timestamp);
    if (parsedTimestamp == null) {
      throw FormatException('Unparseable "timestamp" field', json);
    }

    return WalletBirthdayCheckpointResponseModel(
      height: height,
      hash: hash,
      timestamp: parsedTimestamp.toUtc(),
    );
  }
}
