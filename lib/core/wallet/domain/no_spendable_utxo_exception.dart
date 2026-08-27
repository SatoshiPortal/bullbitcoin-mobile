import 'package:bb_mobile/core/errors/bull_exception.dart';

class NoSpendableUtxoException extends BullException {
  NoSpendableUtxoException(super.message);
}
