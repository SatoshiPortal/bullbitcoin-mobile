import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bull_ui/bull_ui.dart' show Gap;
import 'package:flutter/material.dart';

/// The minimal Bull Nym claim step: one field, no confirmation dialog.
///
/// The nym is a single lifetime claim per wallet, so whichever Get Paid product
/// the user enters first (Lightning Address, Donation Page, Point of Sale) shows
/// exactly this step with exactly this copy. It is presentational: the caller
/// owns the claim call, the validation, and the reserved-name prefilter, so each
/// product keeps its own error mapping and capability gating.
///
/// It lives in this feature's `public/` surface because it is shared Get Paid
/// product UI — business copy and affordances, not core infrastructure — and the
/// three product features render it directly.
class GetPaidNymClaimStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController controller;

  /// True while the claim is in flight — disables the field and the action.
  final bool submitting;

  /// A claim rejection to state above the field (name taken, reserved,
  /// invalid). Anything else stays on the caller's failure surface.
  final String? errorText;

  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  /// Submit-time syntax + reserved-name prefilter, returning the message to
  /// show on the field, or null when the value is acceptable.
  final FormFieldValidator<String> validator;

  const GetPaidNymClaimStep({
    super.key,
    required this.formKey,
    required this.controller,
    required this.submitting,
    required this.errorText,
    required this.onChanged,
    required this.onSubmit,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.loc.getPaidNymClaimTitle,
            style: context.font.titleLarge,
          ),
          const Gap(8),
          Text(
            context.loc.getPaidNymClaimBody,
            style: context.font.bodyMedium?.copyWith(
              color: context.appColors.textMuted,
            ),
          ),
          const Gap(24),
          if (errorText case final message?) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                message,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.error,
                ),
              ),
            ),
            const Gap(12),
          ],
          TextFormField(
            key: const Key('get_paid_nym_claim_field'),
            controller: controller,
            enabled: !submitting,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.done,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 32,
            onChanged: onChanged,
            onFieldSubmitted: (_) => submitting ? null : onSubmit(),
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              labelText: context.loc.getPaidNymLabel,
              helperText: context.loc.getPaidNymClaimHelper,
              // The syntax rule is the only thing worth reading under this
              // field, so it gets the full width (the counter used to squeeze
              // it into an ellipsis) and as many lines as it needs. The 32-char
              // ceiling is already enforced by maxLength and stated in the rule.
              helperMaxLines: 3,
              counterText: '',
            ),
            validator: validator,
          ),
          const Gap(24),
          Semantics(
            liveRegion: submitting,
            label: submitting ? context.loc.getPaidNymClaimSubmitting : null,
            child: BBButton.big(
              key: const Key('get_paid_nym_claim_submit'),
              label: submitting
                  ? context.loc.getPaidNymClaimSubmitting
                  : context.loc.getPaidNymClaimSubmit,
              onPressed: onSubmit,
              disabled: submitting,
              bgColor: context.appColors.primary,
              textColor: context.appColors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
