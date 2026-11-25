import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/interac_answer_problem_l10n.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/flow_status_page.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:exchange/steps.dart';

/// The page of the payout requirement [running] is meeting (Interac
/// security answer, virtual IBAN, virtual payee). Every input and button is a
/// requirements event; the flow wraps it in its own.
class PayoutRequirementView extends StatelessWidget {
  const PayoutRequirementView({
    super.key,
    required this.title,
    required this.running,
    required this.onEvent,
    required this.onBack,
  });

  final String title;
  final RequirementsRunning running;

  /// The flow's back event, on every requirement page.
  final VoidCallback onBack;
  final void Function(RequirementsEvent event) onEvent;

  @override
  Widget build(BuildContext context) => switch (running.current) {
    InteracStep(:final state) => _InteracView(
      state: state,
      onEvent: (event) => onEvent(RequirementInteracEvent(event)),
      onBack: onBack,
    ),
    VirtualIbanStep(:final state) => _virtualIban(context, state),
    VirtualPayeeStep(:final state) => _virtualPayee(context, state),
  };

  Widget _virtualIban(BuildContext context, VirtualIbanState state) {
    void send(VirtualIbanEvent event) =>
        onEvent(RequirementVirtualIbanEvent(event));
    final regular = FlowAction(
      context.loc.recipientsConfidentialSepaUseRegularSepa,
      () => send(const VibanDeclinePressed()),
      primary: false,
    );
    final retry = FlowAction(
      context.loc.retry,
      () => send(const VibanRetryPressed()),
    );
    return switch (state) {
      VibanLoading() ||
      VibanActive() ||
      VibanDeclined() ||
      VibanSessionEnded() => FlowStatusPage(
        title: title,
        onBack: onBack,
        busy: true,
      ),
      VibanLoadFailed(:final problem) => FlowStatusPage(
        title: title,
        onBack: onBack,
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry, regular],
      ),
      VibanIntro(:final ownerName) => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsVirtualIbanIntroTitle,
        message:
            '${context.loc.recipientsVirtualIbanIntroDescription}\n\n'
            '${context.loc.recipientsVirtualIbanAccountOwnerName}: $ownerName\n\n'
            '${context.loc.recipientsVirtualIbanNameWarningDescription}',
        actions: [
          FlowAction(
            context.loc.recipientsVirtualIbanActivate,
            () => send(const VibanCreatePressed()),
          ),
          regular,
        ],
      ),
      VibanCreating() || VibanVerifying() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsVirtualIbanActivatingTitle,
        busy: true,
      ),
      VibanCreateFailed(:final problem) => FlowStatusPage(
        title: title,
        onBack: onBack,
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry, regular],
      ),
      VibanUnverified(:final problem) => FlowStatusPage(
        title: title,
        onBack: onBack,
        message:
            '${context.loc.exchangeStepUnverified}\n${problem.toTranslated(context)}',
        isError: true,
        actions: [retry, regular],
      ),
      VibanActivating() || VibanPaused() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsVirtualIbanActivatingTitle,
        message: context.loc.recipientsVirtualIbanActivatingDescription,
        busy: true,
        actions: [regular],
      ),
      VibanTimedOut() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsVirtualIbanActivatingTitle,
        message: context.loc.exchangeStepTimedOut,
        actions: [retry, regular],
      ),
    };
  }

  Widget _virtualPayee(BuildContext context, VirtualPayeeState state) {
    void send(VirtualPayeeEvent event) =>
        onEvent(RequirementVirtualPayeeEvent(event));
    final regular = FlowAction(
      context.loc.recipientsConfidentialSepaUseRegularSepa,
      () => send(const PayeeDeclinePressed()),
      primary: false,
    );
    final retry = FlowAction(
      context.loc.retry,
      () => send(const PayeeRetryPressed()),
    );
    return switch (state) {
      PayeeLoading() ||
      PayeeActivating() ||
      PayeeActive() ||
      PayeeDeclined() ||
      PayeeSessionEnded() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsConfidentialSepaActivatingTitle,
        busy: true,
      ),
      PayeeLoadFailed(:final problem) => FlowStatusPage(
        title: title,
        onBack: onBack,
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry, regular],
      ),
      PayeeActivateFailed(:final problem) => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsConfidentialSepaNotActivatedTitle,
        message: problem.toTranslated(context),
        isError: true,
        actions: [retry, regular],
      ),
      PayeePending() || PayeePaused() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsConfidentialSepaActivatingTitle,
        message: context.loc.recipientsConfidentialSepaActivatingDescription,
        busy: true,
        actions: [regular],
      ),
      PayeeTimedOut() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsConfidentialSepaActivatingTitle,
        message: context.loc.exchangeStepTimedOut,
        actions: [retry, regular],
      ),
      PayeeUnknownStatus() => FlowStatusPage(
        title: title,
        onBack: onBack,
        headline: context.loc.recipientsConfidentialSepaStatusUnknownTitle,
        message: context.loc.recipientsConfidentialSepaStatusUnknownDescription,
        isError: true,
        actions: [retry, regular],
      ),
    };
  }
}

/// The Interac security question and answer: prefilled from the recipient,
/// checked by the step on Continue (3–40 characters, answer letters, digits
/// and hyphens).
class _InteracView extends StatefulWidget {
  const _InteracView({
    required this.state,
    required this.onEvent,
    required this.onBack,
  });

  final InteracSecurityState state;
  final void Function(InteracSecurityEvent event) onEvent;
  final VoidCallback onBack;

  @override
  State<_InteracView> createState() => _InteracViewState();
}

class _InteracViewState extends State<_InteracView> {
  late final TextEditingController _question;
  late final TextEditingController _answer;

  @override
  void initState() {
    super.initState();
    final (question, answer) = switch (widget.state) {
      InteracEditing(:final question, :final answer) => (question, answer),
      InteracAnswered(:final evidence) => (
        evidence.answer.question,
        evidence.answer.answer,
      ),
    };
    _question = TextEditingController(text: question);
    _answer = TextEditingController(text: answer);
  }

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    final state = widget.state;
    final editing = switch (state) {
      final InteracEditing editing => editing,
      InteracAnswered() => null,
    };
    final problem = editing?.problem?.toTranslated(context);
    return BullScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullTopBar(
              title: context.loc.withdrawInteracSecurityDetailsTitle,
              onBack: widget.onBack,
            ),
            Expanded(
              child: BullScrollableColumn(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BullText(
                    context.loc.recipientsFieldSecurityQuestion,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: colors.text,
                  ),
                  const Gap(8),
                  BullInputText(
                    controller: _question,
                    value: _question.text,
                    maxLength: 40,
                    maxLines: 1,
                    onChanged: (text) =>
                        widget.onEvent(InteracQuestionTyped(text)),
                  ),
                  const Gap(20),
                  BullText(
                    context.loc.recipientsFieldSecurityAnswer,
                    style: context.bullType.body.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    color: colors.text,
                  ),
                  const Gap(8),
                  BullInputText(
                    controller: _answer,
                    value: _answer.text,
                    maxLength: 40,
                    maxLines: 1,
                    enableSuggestions: false,
                    autocorrect: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    onChanged: (text) =>
                        widget.onEvent(InteracAnswerTyped(text)),
                    onDone: (_) =>
                        widget.onEvent(const InteracContinuePressed()),
                  ),
                  const Gap(16),
                  Row(
                    children: [
                      BullCheckbox(
                        checked: editing?.saveAsDefault ?? false,
                        onChanged: (checked) => widget.onEvent(
                          InteracSaveAsDefaultSet(save: checked),
                        ),
                      ),
                      const Gap(8),
                      Expanded(
                        child: BullText(
                          context.loc.withdrawInteracSaveAsDefault,
                          style: context.bullType.body,
                          color: colors.text,
                        ),
                      ),
                    ],
                  ),
                  if (problem != null) ...[
                    const Gap(16),
                    BullText(
                      problem,
                      style: context.bullType.label.copyWith(
                        fontWeight: FontWeight.w400,
                      ),
                      color: colors.error,
                    ),
                  ],
                  const Spacer(),
                  const Gap(24),
                  BullButton.primary(
                    label: context.loc.recipientsContinue,
                    onPressed: editing == null
                        ? null
                        : () => widget.onEvent(const InteracContinuePressed()),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
