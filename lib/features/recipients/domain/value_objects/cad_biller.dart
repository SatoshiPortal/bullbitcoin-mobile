import 'package:meta/meta.dart';

/// VALUE OBJECT: Represents a Canadian biller for bill payments
/// Value objects are immutable and defined by their attributes
/// They have no identity - two CadBillers with same data are equal
@immutable
class CadBiller {
  final String _payeeCode;
  final String _payeeName;

  const CadBiller._({required String payeeCode, required String payeeName})
    : _payeeCode = payeeCode,
      _payeeName = payeeName;

  factory CadBiller.create({
    required String payeeCode,
    required String payeeName,
  }) {
    if (payeeCode.trim().isEmpty) {
      throw ArgumentError('Payee code cannot be empty');
    }
    if (payeeName.trim().isEmpty) {
      throw ArgumentError('Payee name cannot be empty');
    }

    return CadBiller._(
      payeeCode: payeeCode.trim(),
      payeeName: payeeName.trim(),
    );
  }

  String get payeeCode => _payeeCode;
  String get payeeName => _payeeName;
}
