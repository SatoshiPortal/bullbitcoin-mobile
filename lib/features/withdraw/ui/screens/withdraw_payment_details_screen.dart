import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class WithdrawPaymentDetailsScreen extends StatefulWidget {
  const WithdrawPaymentDetailsScreen({super.key});

  @override
  State<WithdrawPaymentDetailsScreen> createState() =>
      _WithdrawPaymentDetailsScreenState();
}

class _WithdrawPaymentDetailsScreenState
    extends State<WithdrawPaymentDetailsScreen> {
  static final _answerPattern = RegExp(r'^[a-zA-ZÀ-ž0-9\-]*$');

  late final TextEditingController _questionController;
  late final TextEditingController _answerController;
  final FocusNode _questionFocusNode = FocusNode();
  final FocusNode _answerFocusNode = FocusNode();
  String? _questionError;
  String? _answerError;
  late bool _saveAsDefault;

  @override
  void initState() {
    super.initState();
    final state = context.read<WithdrawBloc>().state;
    final recipient = state is WithdrawPaymentDetailsInputState
        ? state.recipient
        : null;
    final question = recipient?.securityQuestion ?? '';
    final answer = recipient?.securityAnswer ?? '';
    _questionController = TextEditingController(text: question);
    _answerController = TextEditingController(text: answer);
    _saveAsDefault = question.isNotEmpty && answer.isNotEmpty;
  }

  @override
  void dispose() {
    _questionController.dispose();
    _answerController.dispose();
    _questionFocusNode.dispose();
    _answerFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    final state = context.read<WithdrawBloc>().state;
    if (state.cleanPaymentDetailsInputState == null ||
        state is WithdrawPaymentDetailsInputState &&
            state.isCreatingWithdrawOrder) {
      return;
    }

    final question = _questionController.text.trim();
    final answer = _answerController.text.trim();
    final questionError = _validateQuestion(question);
    final answerError = _validateAnswer(answer);

    setState(() {
      _questionError = questionError;
      _answerError = answerError;
    });
    if (questionError != null || answerError != null) return;

    context.read<WithdrawBloc>().add(
      WithdrawEvent.interacSecurityDetailsSubmitted(
        securityQuestion: question,
        securityAnswer: answer,
        saveAsDefault: _saveAsDefault,
      ),
    );
  }

  String? _validateQuestion(String value) {
    if (value.isEmpty) return context.loc.recipientsValidationFieldRequired;
    if (value.length < 3 || value.length > 40) {
      return context.loc.withdrawInteracSecurityQuestionLengthError;
    }
    return null;
  }

  String? _validateAnswer(String value) {
    if (value.isEmpty) return context.loc.recipientsValidationFieldRequired;
    if (value.length < 3 || value.length > 40) {
      return context.loc.withdrawInteracSecurityAnswerLengthError;
    }
    if (!_answerPattern.hasMatch(value)) {
      return context.loc.withdrawInteracSecurityAnswerFormatError;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isCreatingOrder = context.select(
      (WithdrawBloc bloc) =>
          bloc.state is WithdrawPaymentDetailsInputState &&
          (bloc.state as WithdrawPaymentDetailsInputState)
              .isCreatingWithdrawOrder,
    );
    final withdrawError = context.select(
      (WithdrawBloc bloc) => bloc.state is WithdrawPaymentDetailsInputState
          ? (bloc.state as WithdrawPaymentDetailsInputState).error
          : null,
    );
    final colors = context.bull;

    return BullScaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            BullTopBar(
              title: context.loc.withdrawInteracSecurityDetailsTitle,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: BullScrollableColumn(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                crossAxisAlignment: .stretch,
                children: [
                  BullText(
                    context.loc.recipientsFieldSecurityQuestion,
                    style: context.bullText.bodyLarge,
                    color: colors.text,
                  ),
                  const Gap(8),
                  BullInputText(
                    controller: _questionController,
                    value: _questionController.text,
                    focusNode: _questionFocusNode,
                    maxLength: 40,
                    maxLines: 1,
                    onChanged: (_) {
                      if (_questionError != null) {
                        setState(() => _questionError = null);
                      }
                    },
                    onDone: (_) => _answerFocusNode.requestFocus(),
                  ),
                  if (_questionError != null) ...[
                    const Gap(4),
                    BullText(
                      _questionError!,
                      style: context.bullText.bodySmall,
                      color: colors.error,
                    ),
                  ],
                  const Gap(20),
                  BullText(
                    context.loc.recipientsFieldSecurityAnswer,
                    style: context.bullText.bodyLarge,
                    color: colors.text,
                  ),
                  const Gap(8),
                  BullInputText(
                    controller: _answerController,
                    value: _answerController.text,
                    focusNode: _answerFocusNode,
                    maxLength: 40,
                    maxLines: 1,
                    enableSuggestions: false,
                    autocorrect: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    onChanged: (_) {
                      if (_answerError != null) {
                        setState(() => _answerError = null);
                      }
                    },
                    onDone: (_) {
                      if (!isCreatingOrder) _submit();
                    },
                  ),
                  if (_answerError != null) ...[
                    const Gap(4),
                    BullText(
                      _answerError!,
                      style: context.bullText.bodySmall,
                      color: colors.error,
                    ),
                  ],
                  const Gap(16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () =>
                        setState(() => _saveAsDefault = !_saveAsDefault),
                    child: Row(
                      children: [
                        BullCheckbox(
                          checked: _saveAsDefault,
                          onChanged: (checked) =>
                              setState(() => _saveAsDefault = checked),
                        ),
                        const Gap(8),
                        Expanded(
                          child: BullText(
                            context.loc.withdrawInteracSaveAsDefault,
                            style: context.bullText.bodyMedium,
                            color: colors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (withdrawError != null) ...[
                    const Gap(16),
                    BullText(
                      withdrawError.toTranslated(context),
                      style: context.bullText.bodySmall,
                      color: colors.error,
                    ),
                  ],
                  const Spacer(),
                  const Gap(24),
                  BullButton.big(
                    label: context.loc.recipientsContinue,
                    disabled: isCreatingOrder,
                    onPressed: _submit,
                    bgColor: colors.primary,
                    textColor: colors.onPrimary,
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
