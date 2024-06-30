import 'package:bb_arch/_pkg/wallet/models/wallet.dart';
import 'package:bb_arch/_ui/atoms/bb_button.dart';
import 'package:bb_arch/_ui/atoms/bb_form_field.dart';
import 'package:bb_arch/_ui/molecules/address/address_input.dart';
import 'package:bb_arch/_ui/molecules/fee_rate.dart';
import 'package:bb_arch/_ui/molecules/send/advanced_options.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class SendWidget extends StatefulWidget {
  const SendWidget(
      {super.key,
      this.wallet,
      this.loading = false,
      this.disabled = false,
      this.showLabel = true,
      this.asyncValidateAddress,
      this.onChange,
      this.onSubmit});

  final Wallet? wallet;
  final bool loading;
  final bool disabled;
  final bool showLabel;

  final Future<String?> Function(String)? asyncValidateAddress;

  final void Function(String address, int satsToSend)? onChange;
  final void Function(String address, int satsToSend, double feeRate,
      bool isRbf, List<String> labels)? onSubmit;

  @override
  State<SendWidget> createState() => _SendWidgetState();
}

class _SendWidgetState extends State<SendWidget> {
  TextEditingController addressController = TextEditingController();
  TextEditingController amountController = TextEditingController();
  TextEditingController labelController = TextEditingController();

  String? _addressError;
  bool _isLoading = false;

  void _handleSubmit(BuildContext context) async {
    if (_syncAddressValidate(addressController.text)) {
      if (widget.asyncValidateAddress != null) {
        // TODO: Make sure this error is human friendly.
        final errMsg =
            await widget.asyncValidateAddress!(addressController.text);
        if (errMsg != null) {
          setState(() {
            _addressError = errMsg;
          });
        } else {
          setState(() {
            _addressError = null;
          });

          callOnSubmit();
        }
      } else {
        callOnSubmit();
      }
    }
  }

  bool _syncAddressValidate(String? value) {
    if (value == null || value.isEmpty) {
      setState(() {
        _addressError = 'Please enter address';
      });
      return false;
    }
    return true;
  }

  void callOnSubmit() {
    if (widget.onSubmit != null) {
      widget.onSubmit!(addressController.text, int.parse(amountController.text),
          10, true, []);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        AddressInput(
          addressController: addressController,
          disabled: _isLoading || widget.disabled || widget.loading,
          errorMsg: _addressError ?? '',
        ),
        BBFormField(
          label: 'Amount',
          editingController: amountController,
          keyboardType: TextInputType.number,
          disabled: _isLoading || widget.disabled || widget.loading,
        ),
        if (widget.showLabel)
          BBFormField(
            label: 'Label',
            editingController: labelController,
            disabled: _isLoading || widget.disabled || widget.loading,
          ),
        FeeRateSelector(),
        AdvancedSendOptions(),
        Center(
          child: BBButton(
            label: 'Send',
            isLoading: widget.loading,
            onSubmit: _handleSubmit,
          ),
        ),
      ],
    );
  }
}
