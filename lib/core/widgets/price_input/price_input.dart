import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullAmountInputFormatter,
        BullPickerItem,
        BullPickerMenu,
        BullTypographyX,
        Gap;

class PriceInput extends StatelessWidget {
  const PriceInput({
    super.key,
    required this.currency,
    required this.amountEquivalent,
    required this.availableCurrencies,
    required this.onCurrencyChanged,
    required this.amountController,
    this.error,
    required this.focusNode,
    this.readOnly = false,
    this.isMax = false,
  });

  final String currency;
  final String amountEquivalent;
  final List<String> availableCurrencies;
  final Function(String)? onCurrencyChanged;
  final TextEditingController amountController;
  final String? error;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          error ?? '',
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(
                color: error != null
                    ? context.appColors.error
                    : context.appColors.transparent,
              ),
          maxLines: 2,
        ),
        const Gap(8),
        Row(
          mainAxisAlignment: .center,
          children: [
            const Gap(24),
            Flexible(
              child: FittedBox(
                fit: .scaleDown,
                child: Row(
                  mainAxisSize: .min,
                  children: [
                    IntrinsicWidth(
                      child: isMax
                          ? Text(
                              context.loc.swapMax,
                              style: context.bullType.display.copyWith(
                                color: context.appColors.secondary,
                              ),
                            )
                          : TextField(
                              controller: amountController,
                              focusNode: focusNode,
                              keyboardType: currency == BitcoinUnit.sats.code
                                  ? TextInputType.number
                                  : const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                              inputFormatters: [
                                BullAmountInputFormatter(currency),
                              ],
                              showCursor: !readOnly,
                              readOnly: readOnly,
                              cursorColor: context.appColors.outline,
                              cursorOpacityAnimates: true,
                              cursorHeight: 30,
                              style: context.bullType.display.copyWith(
                                color: context.appColors.secondary,
                              ),
                              textAlign: .center,
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: false,
                                hintText:
                                    focusNode != null && focusNode!.hasFocus
                                    ? null
                                    : "0",
                                hintStyle: context.bullType.display.copyWith(
                                  color: context.appColors.secondary,
                                ),
                              ),
                            ),
                    ),
                    const Gap(8),
                    Text(
                      currency,
                      style: context.bullType.headline.copyWith(
                        color: context.appColors.secondary,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
            if (onCurrencyChanged case final onChanged?
                when availableCurrencies.isNotEmpty)
              BullPickerMenu<String>(
                value: currency,
                tooltip: context.loc.settingsCurrencyTitle,
                items: [
                  for (final code in availableCurrencies)
                    BullPickerItem(
                      value: code,
                      label:
                          '${SupportedCurrency.tryFromCode(code)?.flag ?? '₿'} $code',
                    ),
                ],
                onChanged: onChanged,
                child: Icon(
                  Icons.arrow_drop_down,
                  color: context.appColors.secondary,
                  size: 40,
                ),
              ),
          ],
        ),
        const Gap(14),
        Text(
          // No equivalent (no price): a lone "~" would read as a value.
          amountEquivalent.isEmpty ? '' : '~$amountEquivalent',
          style: context.bullType.body
              .copyWith(fontWeight: FontWeight.w500)
              .copyWith(color: context.appColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
