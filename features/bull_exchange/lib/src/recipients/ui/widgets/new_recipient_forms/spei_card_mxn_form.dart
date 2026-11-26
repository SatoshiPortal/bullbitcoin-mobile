import 'package:bull_exchange/src/recipients/ui/widgets/recipient_server_field_error.dart';
import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/bb_text_form_field.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/recipient_form_continue_button.dart';
import 'package:bull_exchange/src/recipients/presentation/recipients_bloc.dart';
import 'package:bull_exchange/src/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:bull_exchange/src/recipients/presentation/spei_problem_l10n.dart';
import 'package:exchange/exchange.dart'
    show RecipientField, speiDebitCardProblem;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SpeiCardMxnForm extends StatefulWidget {
  const SpeiCardMxnForm({super.key, this.hookError});

  final String? hookError;

  @override
  SpeiCardMxnFormState createState() => SpeiCardMxnFormState();
}

class SpeiCardMxnFormState extends State<SpeiCardMxnForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _institutionCodeFocusNode = FocusNode();
  final FocusNode _debitCardFocusNode = FocusNode();
  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _institutionCode = '';
  String _debitCard = '';
  String _name = '';
  String _label = '';

  @override
  void dispose() {
    _institutionCodeFocusNode.dispose();
    _debitCardFocusNode.dispose();
    _nameFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = SpeiCardMxnFormDataModel(
        institutionCode: _institutionCode,
        debitcard: _debitCard,
        name: _name,
        label: _label.isEmpty ? null : _label,
      );

      context.read<RecipientsBloc>().add(RecipientsEvent.added(formData));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: .start,
        mainAxisSize: .min,
        children: [
          BBTextFormField(
            labelText: context.loc.recipientsFieldInstitutionCode,
            errorText: context.recipientServerFieldError(
              RecipientField.institutionCode,
            ),
            hintText: context.loc.recipientsFieldInstitutionCodeHint,
            focusNode: _institutionCodeFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) => _debitCardFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _institutionCode = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldDebitCard,
            errorText: context.recipientServerFieldError(
              RecipientField.debitcard,
            ),
            hintText: context.loc.recipientsFieldDebitCardHint,
            focusNode: _debitCardFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _nameFocusNode.requestFocus(),
            validator: speiFieldValidator(context, speiDebitCardProblem),
            onChanged: (value) {
              setState(() {
                _debitCard = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldName,
            errorText: context.recipientServerFieldError(RecipientField.name),
            hintText: context.loc.recipientsFieldNameHint,
            focusNode: _nameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _name = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsLabelOptional,
            errorText: context.recipientServerFieldError(RecipientField.label),
            hintText: context.loc.recipientsLabelHint,
            focusNode: _labelFocusNode,
            textInputAction: .done,
            onFieldSubmitted: (_) => _submitForm(),
            validator: null,
            onChanged: (value) {
              setState(() {
                _label = value;
              });
            },
          ),
          const Gap(24.0),
          RecipientFormContinueButton(
            onPressed: _submitForm,
            hookError: widget.hookError,
            shownFields: const {
              RecipientField.institutionCode,
              RecipientField.debitcard,
              RecipientField.name,
              RecipientField.label,
            },
          ),
        ],
      ),
    );
  }
}
