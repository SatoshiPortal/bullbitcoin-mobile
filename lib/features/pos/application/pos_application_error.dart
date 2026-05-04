import 'package:bb_mobile/features/pos/domain/pos_domain_error.dart';

class PosApplicationError implements Exception {
  const PosApplicationError(this.message, {this.cause});

  final String message;
  final Object? cause;

  factory PosApplicationError.from(Object error) {
    if (error is PosDomainError) {
      return PosApplicationError(error.message, cause: error);
    }
    return PosApplicationError('$error', cause: error);
  }

  @override
  String toString() => message;
}
