import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/withdraw/domain/withdraw_payment_description.dart';
import 'package:bull_ui/bull_ui.dart' show BullInputText, Gap;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class WithdrawPaymentDescriptionScreen extends StatefulWidget {
  final String initialDescription;

  const WithdrawPaymentDescriptionScreen({
    this.initialDescription = '',
    super.key,
  });

  @override
  State<WithdrawPaymentDescriptionScreen> createState() =>
      _WithdrawPaymentDescriptionScreenState();
}

class _WithdrawPaymentDescriptionScreenState
    extends State<WithdrawPaymentDescriptionScreen> {
  late final TextEditingController _descriptionController;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    );
  }

  void _continue() {
    final description = WithdrawPaymentDescription.sanitize(
      _descriptionController.text,
    );
    if (!WithdrawPaymentDescription.isValid(description)) {
      setState(() {
        _validationError = context.loc.withdrawPaymentDescriptionTooShort;
      });
      return;
    }
    context.pop(description);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.payDescriptionLabel)),
      body: SafeArea(
        child: ScrollableColumn(
          crossAxisAlignment: .start,
          children: [
            const Gap(24),
            Text(
              context.loc.payDescriptionLabel,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.onSurfaceVariant,
              ),
            ),
            const Gap(8),
            BullInputText(
              controller: _descriptionController,
              value: _descriptionController.text,
              hint: context.loc.payDescriptionHint,
              maxLength: 140,
              onChanged: (_) {
                if (_validationError != null) {
                  setState(() => _validationError = null);
                }
              },
            ),
            if (_validationError case final error?) ...[
              const Gap(8),
              Text(
                error,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ],
            const Spacer(),
            BBButton.big(
              label: context.loc.withdrawAmountContinue,
              onPressed: _continue,
              bgColor: context.appColors.onSurface,
              textColor: context.appColors.surface,
            ),
            const Gap(16),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }
}
