import 'package:silent/localizations.dart';

import '../../localizations.dart';

import 'package:address_view/address_view.dart' show AddressViewer;
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:material_ui/material_ui.dart'
    show MaterialLocalizations, MaterialPageRoute;

import '../../domain/payment_destination.dart';
import '../../domain/validate_payment_destination_usecase.dart';
import 'full_screen_scanner_page.dart';

/// App wiring for the pure destination input. Parsing never navigates forward.
class PaymentDestinationField extends StatefulWidget {
  final String value;
  final String? label;
  final String hint;
  final Set<PaymentDestinationType> acceptedTypes;
  final ValueChanged<String> onChanged;
  final ValueChanged<PaymentDestination?>? onValidated;
  final ValueChanged<bool>? onValidationChanged;
  final bool allowLnurl;
  final bool enabled;
  final String? error;
  final TextInputType? keyboardType;

  const PaymentDestinationField({
    super.key,
    required this.value,
    this.label,
    required this.hint,
    required this.acceptedTypes,
    required this.onChanged,
    this.onValidated,
    this.onValidationChanged,
    this.allowLnurl = true,
    this.enabled = true,
    this.error,
    this.keyboardType,
  });

  @override
  State<PaymentDestinationField> createState() =>
      _PaymentDestinationFieldState();
}

class _PaymentDestinationFieldState extends State<PaymentDestinationField> {
  late String _value;
  PaymentDestination? _destination;
  bool _validated = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _validate(_value);
    });
  }

  @override
  void didUpdateWidget(PaymentDestinationField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((widget.value != oldWidget.value &&
            widget.value != _destination?.address) ||
        widget.allowLnurl != oldWidget.allowLnurl ||
        !setEquals(widget.acceptedTypes, oldWidget.acceptedTypes)) {
      _value = widget.value;
      _destination = null;
      _validated = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _validate(_value);
      });
    }
  }

  Future<void> _validate(String value) async {
    final generation = ++_generation;
    final destination = await const ValidatePaymentDestinationUsecase().execute(
      value,
      acceptedTypes: widget.acceptedTypes,
      allowLnurl: widget.allowLnurl,
    );
    if (!mounted || generation != _generation || value != _value) return;
    setState(() {
      _destination = destination;
      _validated = true;
    });
    widget.onValidationChanged?.call(destination != null);
    widget.onValidated?.call(destination);
  }

  void _change(String value) {
    setState(() {
      _value = value;
      _destination = null;
      _validated = false;
    });
    widget.onChanged(value);
    _validate(value);
  }

  String _kind(PaymentDestinationType type) => switch (type) {
    PaymentDestinationType.bitcoin => addressViewCopy(
      context,
    ).exchangeDcaAddressLabelBitcoin,
    PaymentDestinationType.liquid => addressViewCopy(
      context,
    ).exchangeDcaAddressLabelLiquid,
    PaymentDestinationType.lightningAddress => addressViewCopy(
      context,
    ).exchangeDcaAddressLabelLightning,
  };

  @override
  Widget build(BuildContext context) {
    final destination = _destination;
    final invalid = _validated && _value.isNotEmpty && destination == null;
    final kind = destination == null ? null : _kind(destination.type);
    return BullPaymentDestinationInput(
      value: _value,
      label: widget.label,
      hint: widget.hint,
      enabled: widget.enabled,
      keyboardType:
          widget.keyboardType ??
          (widget.acceptedTypes.length == 1 &&
                  widget.acceptedTypes.contains(
                    PaymentDestinationType.lightningAddress,
                  )
              ? TextInputType.emailAddress
              : TextInputType.text),
      onChanged: _change,
      pasteLabel: MaterialLocalizations.of(context).pasteButtonLabel,
      scanLabel: context.silentLoc.silentScan,
      clearLabel: context.silentLoc.silentClearButton,
      onClear: () => _change(''),
      onPaste: () async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final value = data?.text;
        if (mounted && widget.enabled && value != null) _change(value);
      },
      onScan: () => Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => FullScreenScannerPage(
            onScannedPaymentRequest: (raw) {
              if (mounted && widget.enabled) _change(raw);
            },
          ),
        ),
      ),
      validAddress: destination == null
          ? null
          : AddressViewer(
              destination.address,
              clipboardText: destination.raw,
              style: context.bullType.body,
            ),
      kind: destination?.amountSat != null
          ? addressViewCopy(
              context,
            ).destinationAmountFromQr(kind ?? '', destination?.amountSat ?? 0)
          : kind,
      error:
          widget.error ??
          (invalid
              ? widget.acceptedTypes.length == 1
                    ? addressViewCopy(context).destinationExpectedType(
                        _kind(widget.acceptedTypes.single),
                      )
                    : addressViewCopy(context).sendErrorInvalidAddressOrInvoice
              : null),
    );
  }
}
