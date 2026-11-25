import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/funding/presentation/fund_flow.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullButton,
        BullDropdown,
        BullFadingLinearProgress,
        BullKeyboardActions,
        BullPickerItem,
        BullScrollableColumn,
        BullShapesX,
        BullText,
        BullTypographyX,
        Gap;
import 'package:exchange/exchange.dart';
import 'package:exchange/funding.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// COP pre-step: the paying bank and the amount. The sender name is the
/// account holder's, from the loaded account.
class FundCopInputPage extends StatefulWidget {
  const FundCopInputPage({
    super.key,
    required this.institutions,
    required this.senderName,
    required this.busy,
    required this.onEvent,
  });

  final List<FundingInstitution> institutions;
  final String senderName;
  final bool busy;
  final void Function(FundFlowEvent event) onEvent;

  @override
  State<FundCopInputPage> createState() => _FundCopInputPageState();
}

class _FundCopInputPageState extends State<FundCopInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _amountNode = FocusNode();
  FundingInstitution? _institution;

  @override
  void dispose() {
    _amountController.dispose();
    _amountNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final institution = _institution;
    final amount = CopAmount.parse(_amountController.text);
    if (institution == null || amount == null) return;
    widget.onEvent(FundCopSubmitted(institution, amount));
  }

  InputDecoration _decoration(BuildContext context, Widget suffix) =>
      InputDecoration(
        filled: true,
        fillColor: context.appColors.onSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.bullShapes.input),
          borderSide: BorderSide(color: context.appColors.secondaryFixedDim),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(context.bullShapes.input),
          borderSide: BorderSide(color: context.appColors.secondaryFixedDim),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 14.0,
        ),
        suffixIcon: suffix,
      );

  Widget _label(BuildContext context, String text) => BullText(
    text,
    style: context.bullType.body.copyWith(fontWeight: FontWeight.w500),
    color: context.appColors.secondary,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () => widget.onEvent(const FundBackPressed()),
        ),
        title: Text(context.loc.fundExchangeBankTransfer),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BullFadingLinearProgress(
            height: 3,
            trigger: widget.busy,
            backgroundColor: context.appColors.surface,
            foregroundColor: context.appColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: BullKeyboardActions(
          doneText: context.loc.doneButton,
          disableScroll: true,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: BullScrollableColumn(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: context.appColors.tertiary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        context.bullShapes.card,
                      ),
                      border: Border(
                        left: BorderSide(
                          color: context.appColors.tertiary,
                          width: 4.0,
                        ),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 20,
                          color: context.appColors.onSurface,
                        ),
                        const Gap(8.0),
                        Expanded(
                          child: BullText(
                            context.loc.fundExchangeCopDailyLimitWarning,
                            style: context.bullType.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Gap(24.0),
                  _label(context, context.loc.fundExchangeCopSenderName),
                  const Gap(8.0),
                  TextFormField(
                    initialValue: widget.senderName,
                    readOnly: true,
                    decoration: _decoration(
                      context,
                      IconButton(
                        onPressed: () => Clipboard.setData(
                          ClipboardData(text: widget.senderName),
                        ),
                        icon: const Icon(Icons.copy, size: 20),
                      ),
                    ),
                  ),
                  const Gap(24.0),
                  _label(context, context.loc.fundExchangeCopIssuingBank),
                  const Gap(8.0),
                  BullDropdown<FundingInstitution>(
                    value: _institution,
                    onChanged: (value) => setState(() => _institution = value),
                    validator: (value) => value == null
                        ? context.loc.fundExchangeCopSelectBankError
                        : null,
                    items: [
                      for (final institution in widget.institutions)
                        BullPickerItem(
                          value: institution,
                          label: institution.name,
                        ),
                    ],
                  ),
                  const Gap(24.0),
                  _label(context, context.loc.fundExchangeCopAmount),
                  const Gap(8.0),
                  TextFormField(
                    controller: _amountController,
                    focusNode: _amountNode,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _decoration(
                      context,
                      IconButton(
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (data?.text case final text?) {
                            _amountController.text = text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                          }
                        },
                        icon: const Icon(Icons.content_paste, size: 20),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.loc.fundExchangeCopEnterAmountError;
                      }
                      if (CopAmount.parse(value) == null) {
                        return context.loc.fundExchangeCopValidAmountError;
                      }
                      return null;
                    },
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const Gap(32.0),
                  BullButton.primary(
                    label: context.loc.fundExchangeCopGeneratePaymentLink,
                    onPressed: (widget.busy || _institution == null)
                        ? null
                        : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
