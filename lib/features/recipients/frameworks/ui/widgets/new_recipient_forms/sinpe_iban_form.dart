import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/domain/value_objects/recipient_type.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class SinpeIbanForm extends StatefulWidget {
  const SinpeIbanForm({super.key, this.recipientType, this.hookError});

  final RecipientType? recipientType;
  final String? hookError;

  @override
  SinpeIbanFormState createState() => SinpeIbanFormState();
}

class SinpeIbanFormState extends State<SinpeIbanForm> {
  final _formKey = GlobalKey<FormState>();
  final FocusNode _ibanFocusNode = FocusNode();
  final FocusNode _ownerNameFocusNode = FocusNode();
  final FocusNode _labelFocusNode = FocusNode();
  String _iban = '';
  String _ownerName = '';
  String _label = '';

  @override
  void dispose() {
    _ibanFocusNode.dispose();
    _ownerNameFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      // Determine the correct type based on context
      final type = widget.recipientType ?? RecipientType.sinpeIbanCrc;

      final RecipientFormDataModel formData;
      if (type == RecipientType.sinpeIbanUsd) {
        formData = SinpeIbanUsdFormDataModel(
          iban: _iban,
          ownerName: _ownerName,
          label: _label.isEmpty ? null : _label,
        );
      } else {
        formData = SinpeIbanCrcFormDataModel(
          iban: _iban,
          ownerName: _ownerName,
          label: _label.isEmpty ? null : _label,
        );
      }

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
            labelText: context.loc.recipientsFieldIban,
            hintText: context.loc.recipientsFieldIbanHint,
            focusNode: _ibanFocusNode,
            autofocus: true,
            textInputAction: .next,
            onFieldSubmitted: (_) => _ownerNameFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _iban = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldOwnerName,
            hintText: context.loc.recipientsFieldOwnerNameHint,
            focusNode: _ownerNameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _ownerName = value;
              });
            },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsLabelOptional,
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
          ),
        ],
      ),
    );
  }
}
