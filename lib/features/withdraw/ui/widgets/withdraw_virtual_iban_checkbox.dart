import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Checkbox widget to toggle Virtual IBAN (Confidential SEPA) for EUR withdrawals.
///
/// This widget is only shown when:
/// 1. The selected currency is EUR
/// 2. The user has an active Virtual IBAN
class WithdrawVirtualIbanCheckbox extends StatelessWidget {
  const WithdrawVirtualIbanCheckbox({
    super.key,
    required this.fiatCurrencyCode,
  });

  final String fiatCurrencyCode;

  @override
  Widget build(BuildContext context) {
    // Only show for EUR currency
    if (fiatCurrencyCode != 'EUR') {
      return const SizedBox.shrink();
    }

    return BlocSelector<WithdrawBloc, WithdrawState, (bool, bool)>(
      selector: (state) {
        if (state is WithdrawAmountInputState) {
          return (state.hasActiveVirtualIban, state.useVirtualIban);
        }
        return (false, false);
      },
      builder: (context, data) {
        final (hasActiveVirtualIban, useVirtualIban) = data;

        // Only show checkbox if user has an active Virtual IBAN
        if (!hasActiveVirtualIban) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: context.appColors.outline.withValues(alpha: 0.4),
              ),
            ),
            child: CheckboxListTile(
              value: useVirtualIban,
              onChanged: (value) {
                context.read<WithdrawBloc>().add(
                  WithdrawEvent.useVirtualIbanToggled(value ?? false),
                );
              },
              title: Text(
                context.loc.useVirtualIban,
                style: context.font.bodyLarge?.copyWith(
                  color: context.appColors.onSurface,
                ),
              ),
              subtitle: Text(
                context.loc.useVirtualIbanSubtitle,
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.onSurfaceVariant,
                ),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ),
        );
      },
    );
  }
}
