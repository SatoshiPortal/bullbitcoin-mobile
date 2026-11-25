import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

class ValidateDefaultWalletDestinationUsecase {
  final Future<String?> Function(BtcNetwork type, String raw) _validate;

  const ValidateDefaultWalletDestinationUsecase(this._validate);

  @useResult
  Future<String?> execute(BtcNetwork type, String input) =>
      _validate(type, input);
}
