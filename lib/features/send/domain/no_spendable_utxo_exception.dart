import 'package:primitives/legacy_exceptions.dart';

class NoSpendableUtxoException extends BullException {
  NoSpendableUtxoException(super.message);
}
