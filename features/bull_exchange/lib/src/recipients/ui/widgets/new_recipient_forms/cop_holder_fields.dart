import 'package:bull_exchange/src/exchange_l10n.dart';
import 'package:bull_exchange/src/recipients/presentation/models/recipient_form_data_model.dart';
import 'package:bull_exchange/src/recipients/ui/widgets/bb_text_form_field.dart';
import 'package:bull_ui/bull_ui.dart' show BullLowerCaseTextFormatter, Gap;
import 'package:exchange/exchange.dart' show emailLooksValid;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// The holder and email fields of a Colombian recipient (PSE and Nequi):
/// a corporate toggle, then first and last name for a person or the
/// corporate name for a company, then the email the API requires for both.
///
/// Reports every change through [onChanged].
class CopHolderFields extends StatefulWidget {
  const CopHolderFields({super.key, required this.onChanged, this.onDone});

  final void Function(CopHolderFormData holder, String email) onChanged;

  /// Called when the user submits the last field.
  final VoidCallback? onDone;

  @override
  State<CopHolderFields> createState() => _CopHolderFieldsState();
}

class _CopHolderFieldsState extends State<CopHolderFields> {
  final _lastNameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  bool _isCorporate = false;
  String _firstName = '';
  String _lastName = '';
  String _corporateName = '';
  String _email = '';

  @override
  void dispose() {
    _lastNameFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    setState(change);
    widget.onChanged(
      _isCorporate
          ? CopCorporateFormData(corporateName: _corporateName)
          : CopIndividualFormData(firstName: _firstName, lastName: _lastName),
      _email,
    );
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty)
      ? context.loc.recipientsValidationFieldRequired
      : null;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: .start,
      mainAxisSize: .min,
      children: [
        CheckboxListTile(
          title: Text(context.loc.recipientsFieldCorporateAccount),
          value: _isCorporate,
          onChanged: (value) => _update(() {
            _isCorporate = value ?? false;
            // The fields of the other kind of holder are gone with their
            // text, so their values go too.
            _firstName = '';
            _lastName = '';
            _corporateName = '';
          }),
          contentPadding: EdgeInsets.zero,
          controlAffinity: .leading,
        ),
        const Gap(12.0),
        if (_isCorporate)
          BBTextFormField(
            key: const ValueKey('copCorporateName'),
            labelText: context.loc.recipientsFieldCorporateName,
            hintText: context.loc.recipientsFieldCorporateNameHint,
            textInputAction: .next,
            onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
            validator: _required,
            onChanged: (value) => _update(() => _corporateName = value),
          )
        else ...[
          BBTextFormField(
            key: const ValueKey('copFirstName'),
            labelText: context.loc.recipientsFieldFirstName,
            hintText: context.loc.recipientsFieldFirstNameHint,
            textInputAction: .next,
            onFieldSubmitted: (_) => _lastNameFocusNode.requestFocus(),
            validator: _required,
            onChanged: (value) => _update(() => _firstName = value),
          ),
          const Gap(12.0),
          BBTextFormField(
            key: const ValueKey('copLastName'),
            labelText: context.loc.recipientsFieldLastName,
            hintText: context.loc.recipientsFieldLastNameHint,
            focusNode: _lastNameFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _emailFocusNode.requestFocus(),
            validator: _required,
            onChanged: (value) => _update(() => _lastName = value),
          ),
        ],
        const Gap(12.0),
        BBTextFormField(
          key: const ValueKey('copEmail'),
          labelText: context.loc.recipientsFieldEmailAddress,
          hintText: context.loc.recipientsFieldEmailAddressHint,
          focusNode: _emailFocusNode,
          inputFormatters: [
            FilteringTextInputFormatter.deny(RegExp(r'\s')),
            BullLowerCaseTextFormatter(),
          ],
          textInputAction: .next,
          onFieldSubmitted: (_) => widget.onDone?.call(),
          validator: (v) =>
              _required(v) ??
              (emailLooksValid(v!)
                  ? null
                  : context.loc.recipientsValidationEmailInvalid),
          onChanged: (value) => _update(() => _email = value),
        ),
      ],
    );
  }
}
