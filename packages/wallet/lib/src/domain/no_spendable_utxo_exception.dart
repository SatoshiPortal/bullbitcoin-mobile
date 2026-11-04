import 'package:primitives/primitives.dart' show BullException;

class NoSpendableUtxoException extends BullException {
  NoSpendableUtxoException(super.message);
}
