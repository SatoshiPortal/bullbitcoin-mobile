import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/amount_input_formatter.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PriceInput extends StatelessWidget {
  const PriceInput({
    super.key,
    required this.currency,
    required this.amountEquivalent,
    required this.availableCurrencies,
    required this.onCurrencyChanged,
    required this.onNoteChanged,
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
  final Function(String)? onNoteChanged;
  final TextEditingController amountController;
  final String? error;
  final FocusNode? focusNode;
  final bool readOnly;
  final bool isMax;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BBText(
          error ?? '',
          style: context.font.bodyLarge,
          color: error != null ? context.colour.error : Colors.transparent,
          maxLines: 2,
        ),
        const Gap(8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Gap(24),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IntrinsicWidth(
                      child:
                          isMax
                              ? Text(
                                'MAX',
                                style: context.font.displaySmall!.copyWith(
                                  fontSize: 36,
                                  color: context.colour.outlineVariant,
                                ),
                              )
                              : TextField(
                                controller: amountController,
                                focusNode: focusNode,
                                keyboardType: TextInputType.none,
                                inputFormatters: [
                                  AmountInputFormatter(currency),
                                ],
                                showCursor: !readOnly,
                                readOnly: readOnly,
                                cursorColor: context.colour.outline,
                                cursorOpacityAnimates: true,
                                cursorHeight: 30,
                                style: context.font.displaySmall!.copyWith(
                                  fontSize: 36,
                                  color: context.colour.outlineVariant,
                                ),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  isDense: false,
                                  hintText:
                                      focusNode != null && focusNode!.hasFocus
                                          ? null
                                          : "0",
                                  hintStyle: context.font.displaySmall!
                                      .copyWith(
                                        fontSize: 36,
                                        color: context.colour.outlineVariant,
                                      ),
                                ),
                              ),
                    ),
                    const Gap(8),
                    BBText(
                      currency,
                      style: context.font.displaySmall,
                      color: context.colour.outlineVariant,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ),
            const Gap(16),
            if (availableCurrencies.isNotEmpty && onCurrencyChanged != null)
              InkWell(
                onTap: () async {
                  final selected = await _openPopup(context, currency);
                  if (selected != null && onCurrencyChanged != null) {
                    onCurrencyChanged!(selected);
                  }
                },
                child: Icon(
                  Icons.arrow_drop_down,
                  color: context.colour.secondary,
                  size: 40,
                ),
              ),
          ],
        ),
        const Gap(14),
        BBText(
          '~$amountEquivalent',
          style: context.font.bodyLarge,
          color: context.colour.surfaceContainer,
        ),
        const Gap(14),
        if (onNoteChanged != null)
          Center(
            child: Container(
              height: 50,
              width: 200,
              alignment: Alignment.center,
              child: TextField(
                onChanged: onNoteChanged,
                textAlignVertical: TextAlignVertical.center,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(2),
                    borderSide: BorderSide.none,
                  ),
                  fillColor: context.colour.secondaryFixedDim,
                  filled: true,
                  hintText: 'Add note',
                  hintStyle: context.font.labelSmall!.copyWith(
                    color: context.colour.surfaceContainer,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<String?> _openPopup(BuildContext context, String selected) async {
    final c = await showModalBottomSheet<String?>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colour.secondaryFixedDim,
      constraints: const BoxConstraints(maxWidth: double.infinity),
      builder: (context) {
        return CurrencyBottomSheet(
          availableCurrencies: availableCurrencies,
          selectedValue: selected,
        );
      },
    );

    return c;
  }
}

class CurrencyBottomSheet extends StatelessWidget {
  const CurrencyBottomSheet({
    super.key,
    required this.availableCurrencies,
    required this.selectedValue,
  });

  final List<String> availableCurrencies;
  final String selectedValue;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Gap(16),
        Row(
          children: [
            const Gap(16 * 3),
            const Spacer(),
            BBText('Currency', style: context.font.headlineMedium),
            const Spacer(),
            IconButton(
              iconSize: 20,
              onPressed: () => Navigator.pop(context),
              color: context.colour.secondary,
              icon: const Icon(Icons.close),
            ),
            const Gap(16),
          ],
        ),
        const Gap(24),
        for (final curr in availableCurrencies) ...[
          InkWell(
            onTap: () => Navigator.pop(context, curr),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 40),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: BBText(
                      curr.currencyIcon,
                      style: context.font.headlineSmall,
                    ),
                  ),
                  const Gap(16),
                  BBText(
                    curr,
                    style: context.font.headlineSmall,
                    color:
                        selectedValue == curr
                            ? context.colour.primary
                            : context.colour.secondary,
                    textAlign: TextAlign.start,
                  ),
                ],
              ),
            ),
          ),
        ],
        const Gap(24),
      ],
    );
  }
}

extension _CurrencyStrEx on String {
  String get currencyIcon {
    switch (this) {
      case 'USD':
        return '🇺🇸';
      case 'EUR':
        return '🇪🇺';
      case 'FR':
        return '🇫🇷';
      case 'CAD':
        return '🇨🇦';
      case 'INR':
        return '🇮🇳';
      case 'CRC':
        return '🇨🇷';
      case 'MXN':
        return '🇲🇽';
      case 'sats':
      case 'BTC':
      default:
        return '₿';
    }
  }
}
