import 'package:meta/meta.dart';

/// Resolves an external Buy payout without accepting another payment rail.
class ValidateBuyDestinationUsecase {
  final Future<String?> Function(String) _validate;

  const ValidateBuyDestinationUsecase(this._validate);

  @useResult
  Future<String?> execute(String input) => _validate(input);
}
