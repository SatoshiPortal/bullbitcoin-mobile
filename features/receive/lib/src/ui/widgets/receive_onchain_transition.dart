import 'package:bull_ui/bull_ui.dart';
import 'package:receive/src/presentation/receive_payment_progress.dart';

class ReceiveOnchainTransition extends StatelessWidget {
  final BullPaymentNetwork network;
  final bool confirmed;
  final List<String> steps;
  final String viewDetails;
  final String networkLabel;
  final VoidCallback onBack;
  final VoidCallback onViewDetails;

  const ReceiveOnchainTransition({
    super.key,
    required this.network,
    required this.confirmed,
    required this.steps,
    required this.viewDetails,
    required this.networkLabel,
    required this.onBack,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: networkLabel,
    child: BullPaymentTransition(
      network: network,
      direction: BullPaymentDirection.incoming,
      phase: receiveOnchainPhase(confirmed: confirmed),
      progress: receiveOnchainProgress(steps: steps, confirmed: confirmed),
      status: steps[confirmed ? 1 : 0],
      statusTag: steps[confirmed ? 1 : 0],
      skipLabel: viewDetails,
      onSkip: onViewDetails,
      onBack: onBack,
      onDone: () {},
    ),
  );
}
