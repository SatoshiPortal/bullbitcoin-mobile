import 'dart:async';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/bb_text_form_field.dart';
import 'package:bb_mobile/features/recipients/frameworks/ui/widgets/recipient_form_continue_button.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/bloc/recipients_bloc.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/cad_biller_view_model.dart';
import 'package:bb_mobile/features/recipients/interface_adapters/presenters/models/recipient_form_data_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;

class BillPaymentCadForm extends StatefulWidget {
  const BillPaymentCadForm({super.key, this.hookError});

  final String? hookError;

  @override
  BillPaymentCadFormState createState() => BillPaymentCadFormState();
}

class BillPaymentCadFormState extends State<BillPaymentCadForm> {
  final _formKey = GlobalKey<FormState>();
  List<CadBillerViewModel>? _cadBillers;
  CadBillerViewModel? _selectedBiller;
  final FocusNode _accountNumberFocusNode = FocusNode();
  String _payeeAccountNumber = '';
  final FocusNode _labelFocusNode = FocusNode();
  String _label = '';

  @override
  void dispose() {
    _accountNumberFocusNode.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  Future<void> _searchBiller(String query) {
    final Completer<void> completer = Completer<void>();
    StreamSubscription<RecipientsState>? stateStreamSubscription;
    stateStreamSubscription = context.read<RecipientsBloc>().stream.listen((
      state,
    ) {
      // Update CAD billers when they change in the state, which happens
      // after a successful biller search.
      if (state.isSearchingCadBillers == false) {
        setState(() {
          _cadBillers = state.cadBillers;
        });
        stateStreamSubscription?.cancel();
        completer.complete();
      }
    });
    context.read<RecipientsBloc>().add(
      RecipientsEvent.cadBillersSearched(query),
    );
    return completer.future;
  }

  void _submitForm() {
    if (_formKey.currentState?.validate() ?? false) {
      final formData = BillPaymentCadFormDataModel(
        payeeName: _selectedBiller!.payeeName,
        payeeCode: _selectedBiller!.payeeCode,
        payeeAccountNumber: _payeeAccountNumber,
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
          Autocomplete<CadBillerViewModel>(
            optionsBuilder: (TextEditingValue textEditingValue) async {
              await _searchBiller(textEditingValue.text);
              return _cadBillers?.where(
                    (biller) => biller.payeeName.toLowerCase().contains(
                      textEditingValue.text.toLowerCase(),
                    ),
                  ) ??
                  const Iterable<CadBillerViewModel>.empty();
            },
            displayStringForOption: (CadBillerViewModel biller) =>
                biller.payeeName,
            onSelected: (CadBillerViewModel biller) {
              setState(() {
                _selectedBiller = biller;
              });
              // Move focus to account number field after selection
              _accountNumberFocusNode.requestFocus();
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
                  return BBTextFormField(
                    prefix: const Icon(Icons.search),
                    labelText: context.loc.recipientsFieldBillerName,
                    hintText: context.loc.recipientsFieldBillerNameHint,
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: (value) {
                      setState(() {
                        _selectedBiller = null;
                      });
                    },
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.loc.recipientsValidationBillerSearchMin
                        : _selectedBiller == null
                        ? context.loc.recipientsValidationBillerSelect
                        : null,
                    textInputAction: .next,
                  );
                },
          ),
          const Gap(12.0),
          BBTextFormField(
            labelText: context.loc.recipientsFieldPayeeAccountNumber,
            hintText: context.loc.recipientsFieldAccountNumberHint,
            focusNode: _accountNumberFocusNode,
            textInputAction: .next,
            onFieldSubmitted: (_) => _labelFocusNode.requestFocus(),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? context.loc.recipientsValidationFieldRequired
                : null,
            onChanged: (value) {
              setState(() {
                _payeeAccountNumber = value;
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
