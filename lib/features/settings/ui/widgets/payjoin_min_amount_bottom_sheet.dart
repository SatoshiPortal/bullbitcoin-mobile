import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

/// Bottom sheet to edit the payjoin minimum receive amount (in sats).
///
/// Returns the entered amount on save, or null on dismiss.
class PayjoinMinAmountBottomSheet extends StatefulWidget {
  final int initialAmountSat;

  const PayjoinMinAmountBottomSheet({
    super.key,
    required this.initialAmountSat,
  });

  // Bounds kept in one place; also used to validate input. 1000 sats is just
  // above dust, effectively "always payjoin"; 21_000_000 sats (0.21 BTC) is a
  // deliberately high "only large amounts" ceiling.
  static const int minSat = 1000;
  static const int maxSat = 21000000;

  static Future<int?> show(
    BuildContext context, {
    required int initialAmountSat,
  }) {
    return BlurredBottomSheet.show<int>(
      context: context,
      child: PayjoinMinAmountBottomSheet(initialAmountSat: initialAmountSat),
    );
  }

  @override
  State<PayjoinMinAmountBottomSheet> createState() =>
      _PayjoinMinAmountBottomSheetState();
}

class _PayjoinMinAmountBottomSheetState
    extends State<PayjoinMinAmountBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initialAmountSat.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final parsed = int.tryParse(value?.trim() ?? '');
    if (parsed == null ||
        parsed < PayjoinMinAmountBottomSheet.minSat ||
        parsed > PayjoinMinAmountBottomSheet.maxSat) {
      return context.loc.settingsPayjoinMinAmountRangeError(
        PayjoinMinAmountBottomSheet.minSat,
        PayjoinMinAmountBottomSheet.maxSat,
      );
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(int.parse(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.loc.settingsPayjoinMinAmountTitle,
              style: context.font.headlineSmall,
            ),
            const Gap(8),
            Text(
              context.loc.settingsPayjoinMinAmountDescription,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.textMuted,
              ),
            ),
            const Gap(16),
            TextFormField(
              controller: _controller,
              focusNode: _focusNode,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                suffixText: context.loc.sendSats,
                border: const OutlineInputBorder(),
              ),
              validator: _validate,
              onFieldSubmitted: (_) => _save(),
            ),
            const Gap(24),
            BBButton.big(
              label: context.loc.save,
              onPressed: _save,
              bgColor: context.appColors.secondary,
              textColor: context.appColors.onSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
