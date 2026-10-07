import 'transaction_position.dart';
import 'transaction_input.dart';
import 'transaction_output.dart';

class WalletTransaction {
  final String txid;
  final int amountSats;
  final int feeSats;
  final List<TransactionInput> inputs;
  final List<TransactionOutput> outputs;
  final int? inputCount;
  final int? outputCount;
  final TransactionDirection? direction;
  final bool? selfTransfer;
  final int? vsize;
  final TransactionPosition position;
  final Map<String, Object?> evidence;
  final Map<String, Object?> details;

  WalletTransaction({
    required this.txid,
    required this.amountSats,
    this.feeSats = 0,
    List<TransactionInput> inputs = const [],
    List<TransactionOutput> outputs = const [],
    required this.position,
    this.inputCount,
    this.outputCount,
    this.direction,
    this.selfTransfer,
    this.vsize,
    Map<String, Object?> evidence = const {},
    Map<String, Object?> details = const {},
  }) : inputs = List.unmodifiable(inputs),
       outputs = List.unmodifiable(outputs),
       evidence = _deepUnmodifiableMap(evidence),
       details = _deepUnmodifiableMap(details);
}

enum TransactionDirection { incoming, outgoing }

Map<String, Object?> _deepUnmodifiableMap(Map<String, Object?> value) =>
    Map.unmodifiable(
      value.map((key, item) => MapEntry(key, _deepUnmodifiable(item))),
    );

Object? _deepUnmodifiable(Object? value) {
  if (value is Map<String, Object?>) return _deepUnmodifiableMap(value);
  if (value is Map) {
    return Map.unmodifiable(
      value.map((key, item) => MapEntry(key, _deepUnmodifiable(item))),
    );
  }
  if (value is List) return List.unmodifiable(value.map(_deepUnmodifiable));
  if (value is Set) return Set.unmodifiable(value.map(_deepUnmodifiable));
  return value;
}
