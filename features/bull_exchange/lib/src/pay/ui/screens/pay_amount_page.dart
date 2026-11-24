import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/pay/presentation/pay_flow.dart';
import 'package:bull_exchange/src/steps_l10n.dart';
import 'package:bull_exchange/src/ui/amount_problem_l10n.dart';
import 'package:bull_exchange/src/ui/widgets/exchange_amount_input_field.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullButton, BullScrollableColumn, BullTypographyX, Gap;
import 'package:exchange/steps.dart';
import 'package:material_ui/material_ui.dart';

/// The amount step of the pay flow while it is editing: the recipient's
/// currency and a description. The step checks it on Continue.
class PayAmountPage extends StatefulWidget {
  const PayAmountPage({
    super.key,
    required this.editing,
    required this.onEvent,
  });

  final AmountEditing editing;
  final void Function(PayFlowEvent event) onEvent;

  @override
  State<PayAmountPage> createState() => _PayAmountPageState();
}

class _PayAmountPageState extends State<PayAmountPage> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.editing.draft.text,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.editing.draft.description,
  );
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _amount.addListener(_typed);
    _description.addListener(_described);
  }

  @override
  void didUpdateWidget(PayAmountPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final draft = widget.editing.draft;
    if (draft.text != _amount.text) _amount.text = draft.text;
    if (draft.description != _description.text) {
      _description.text = draft.description;
    }
  }

  void _typed() {
    if (_amount.text == widget.editing.draft.text) return;
    widget.onEvent(PayAmountChanged(AmountTyped(_amount.text)));
  }

  void _described() {
    if (_description.text == widget.editing.draft.description) return;
    widget.onEvent(
      PayAmountChanged(AmountDescriptionTyped(_description.text)),
    );
  }

  @override
  void dispose() {
    _amount.removeListener(_typed);
    _description.removeListener(_described);
    _amount.dispose();
    _description.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final market = editing.draft.market;
    final problem = editing.problem;
    final quote = editing.quote;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.payTitle),
        leading: BackButton(
          onPressed: () => widget.onEvent(const PayBackPressed()),
        ),
      ),
      body: SafeArea(
        child: BullScrollableColumn(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Gap(40),
            ExchangeAmountInputField(
              amountController: _amount,
              focusNode: _focus,
              fiatCurrency: market.currency,
            ),
            const Gap(16),
            TextField(
              controller: _description,
              maxLength: 140,
              decoration: InputDecoration(
                labelText: context.loc.payPaymentDescription,
              ),
            ),
            if (problem != null) ...[
              const Gap(16),
              Text(
                problem.toTranslated(context, market.currency.code),
                style: context.bullType.body.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ],
            if (quote case RateFailed(:final problem)) ...[
              const Gap(16),
              Text(
                problem.toTranslated(context),
                style: context.bullType.body.copyWith(
                  color: context.appColors.error,
                ),
              ),
              const Gap(8),
              BullButton.secondary(
                label: context.loc.retry,
                onPressed: () => widget.onEvent(
                  const PayAmountChanged(AmountRateRetryPressed()),
                ),
              ),
            ],
            const Spacer(),
            BullButton.primary(
              label: context.loc.payContinue,
              onPressed: () => widget.onEvent(
                const PayAmountChanged(AmountContinuePressed()),
              ),
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }
}
