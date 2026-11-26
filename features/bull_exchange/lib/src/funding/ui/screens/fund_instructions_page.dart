import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/funding/domain/fund_flow.dart';
import 'package:bull_exchange/src/funding/ui/widgets/funding_instructions_view.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullInfoCard;
import 'package:exchange/funding.dart';
import 'package:material_ui/material_ui.dart';

/// A rail's instructions, with Done.
class FundInstructionsPage extends StatelessWidget {
  const FundInstructionsPage({
    super.key,
    required this.rail,
    required this.instructions,
    required this.onOpenLink,
    required this.onEvent,
  });

  final FundingRail rail;
  final FundingInstructions instructions;
  final void Function(Uri link) onOpenLink;
  final void Function(FundFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(onPressed: () => onEvent(const FundBackPressed())),
        title: Text(context.loc.fundExchangeTitle),
        scrolledUnderElevation: 0.0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: FundingInstructionsView(
            rail: rail,
            instructions: instructions,
            onOpenLink: onOpenLink,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: BullButton.secondary(
            label: context.loc.fundExchangeDoneButton,
            onPressed: () => onEvent(const FundDonePressed()),
          ),
        ),
      ),
    );
  }
}

/// Why there are no instructions: a refusal (Back only) or a failed read
/// (Retry). Never a page with placeholder values (FUND-1).
class FundProblemPage extends StatelessWidget {
  const FundProblemPage({
    super.key,
    required this.title,
    required this.message,
    required this.onEvent,
    this.canRetry = false,
  });

  final String? title;
  final String message;
  final bool canRetry;
  final void Function(FundFlowEvent event) onEvent;

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(onPressed: () => onEvent(const FundBackPressed())),
        title: Text(context.loc.fundExchangeTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProblemCard(title: title, message: message),
              const SizedBox(height: 24.0),
              if (canRetry)
                BullButton.primary(
                  label: context.loc.retry,
                  onPressed: () => onEvent(const FundRetryPressed()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.title, required this.message});

  final String? title;
  final String message;

  @override
  Widget build(BuildContext context) => BullInfoCard(
    title: title,
    description: message,
    bgColor: context.appColors.error.withValues(alpha: 0.1),
    tagColor: context.appColors.primary,
  );
}
