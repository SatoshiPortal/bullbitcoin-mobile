import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow.dart';
import 'package:bull_exchange/src/funding/ui/widgets/fund_exchange_scam_warning_card.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullFadingLinearProgress,
        BullShapesX,
        BullText,
        BullTypographyX,
        Gap;
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// The scam-warning consent, shown exactly while the consent gate asks,
/// sends, re-reads or failed (FUND-7, FUND-8). It cannot be dismissed while
/// the consent is being sent or re-read.
class FundConsentSheet extends StatefulWidget {
  const FundConsentSheet({
    super.key,
    required this.gate,
    required this.onEvent,
  });

  final ConsentGateState gate;
  final void Function(FundFlowEvent event) onEvent;

  @override
  State<FundConsentSheet> createState() => _FundConsentSheetState();
}

class _FundConsentSheetState extends State<FundConsentSheet> {
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    final gate = widget.gate;
    final busy = switch (gate) {
      ConsentSubmitting() || ConsentVerifying() => true,
      ConsentRequired() ||
      ConsentAsking() ||
      ConsentFailed() ||
      ConsentUnverified() ||
      ConsentGateGiven() ||
      ConsentDeclined() ||
      ConsentSessionEnded() => false,
    };
    final problem = switch (gate) {
      ConsentFailed() => context.loc.fundExchangeScamConsentError,
      ConsentUnverified() => context.loc.fundExchangeScamConsentUnverified,
      ConsentRequired() ||
      ConsentAsking() ||
      ConsentSubmitting() ||
      ConsentVerifying() ||
      ConsentGateGiven() ||
      ConsentDeclined() ||
      ConsentSessionEnded() => null,
    };
    final retry = gate is ConsentFailed || gate is ConsentUnverified;
    return PopScope(
      canPop: !busy,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BullFadingLinearProgress(
            height: 3,
            trigger: busy,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: context.appColors.tertiary,
                    child: Icon(
                      Icons.shield_outlined,
                      size: 28,
                      color: context.appColors.onSurface,
                    ),
                  ),
                  const Gap(8.0),
                  BullText(
                    context.loc.fundExchangeWarningTitle,
                    style: context.bullType.headline,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(4.0),
                  BullText(
                    context.loc.fundExchangeWarningDescription,
                    style: context.bullType.subtitle.copyWith(
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const Gap(16.0),
                  const FundExchangeScamWarningCard(),
                ],
              ),
            ),
          ),
          Padding(
            // The sheet may be full height: keep the button out of the
            // system gesture zone.
            padding: EdgeInsets.fromLTRB(
              16.0,
              16.0,
              16.0,
              MediaQuery.paddingOf(context).bottom + 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!retry)
                  CheckboxListTile(
                    tileColor: context.appColors.secondaryFixedDim,
                    contentPadding: const EdgeInsets.all(8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                    ),
                    value: _confirmed,
                    onChanged: busy
                        ? null
                        : (value) =>
                              setState(() => _confirmed = value ?? false),
                    title: BullText(
                      context.loc.fundExchangeWarningConfirmation,
                      style: context.bullType.body.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                const Gap(16.0),
                if (problem != null) ...[
                  BullText(
                    problem,
                    style: context.bullType.body,
                    color: Theme.of(context).colorScheme.error,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8.0),
                ],
                if (retry)
                  BullButton.primary(
                    label: context.loc.retry,
                    onPressed: () => widget.onEvent(const FundRetryPressed()),
                  )
                else
                  BullButton.primary(
                    label: context.loc.fundExchangeContinueButton,
                    onPressed: (!_confirmed || busy)
                        ? null
                        : () => widget.onEvent(const FundConsentAccepted()),
                  ),
                const Gap(8.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
