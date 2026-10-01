import 'package:bb_mobile/features/recipients/domain/entities/recipient.dart';

class SepaVirtualPayeeActivationProgress {
  final Recipient recipient;
  final bool initialWaitTimedOut;

  const SepaVirtualPayeeActivationProgress({
    required this.recipient,
    required this.initialWaitTimedOut,
  });
}
