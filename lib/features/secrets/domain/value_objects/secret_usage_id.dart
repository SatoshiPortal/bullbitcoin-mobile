import 'package:meta/meta.dart';

@immutable
class SecretUsageId {
  final int value;

  const SecretUsageId(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecretUsageId &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'SecretUsageId($value)';
}
