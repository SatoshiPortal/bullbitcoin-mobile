import 'package:bb_mobile/core/errors/bull_exception.dart';

class InconsistentWalletStateException extends BullException {
  final String fingerprint;

  InconsistentWalletStateException({required this.fingerprint})
    : super('Wallet records without a seed for fingerprint: $fingerprint');
}
