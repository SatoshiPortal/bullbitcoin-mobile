import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class PriceInput extends StatelessWidget {
  const PriceInput({
    super.key,
    required this.amount,
    required this.currency,
    required this.amountEquivalent,
    required this.availableCurrencies,
    required this.onCurrencyChanged,
    required this.onNoteChanged,
  });

  final String amount;
  final String currency;
  final String amountEquivalent;
  final List<String> availableCurrencies;
  final Function(String) onCurrencyChanged;
  final Function(String) onNoteChanged;

  @override
  Widget build(BuildContext context) {
    // Needed to position the currency dropdown underneat it.
    final equivalentKey = GlobalKey();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            BBText(
              amount.isEmpty ? '0' : amount,
              style: context.font.displaySmall!.copyWith(
                fontSize: 36,
              ),
              color: context.colour.outlineVariant,
            ),
            const Gap(8),
            BBText(
              currency,
              style: context.font.displaySmall,
              color: context.colour.outlineVariant,
            ),
            const Gap(16),
            InkWell(
              onTap: () async {
                final renderBox = equivalentKey.currentContext!
                    .findRenderObject()! as RenderBox;
                final offset = renderBox.localToGlobal(Offset.zero) / 3;
                final size = renderBox.size;
                final screenWidth = MediaQuery.of(context).size.width;
                const menuWidth = 148.0;

                final left = screenWidth / 2 - menuWidth / 2;

                final selected = await showMenu<String>(
                  context: context,
                  color: context.colour.onPrimary,
                  position: RelativeRect.fromLTRB(
                    left,
                    offset.dy + size.height + 8,
                    left,
                    0,
                  ),
                  items: [
                    PopupMenuItem<String>(
                      enabled: false,
                      padding: EdgeInsets.zero,
                      child: SizedBox(
                        height: 138,
                        width: menuWidth, // Match your design
                        child: Scrollbar(
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: availableCurrencies.length,
                            itemBuilder: (context, index) {
                              final code = availableCurrencies[index];
                              return InkWell(
                                onTap: () => Navigator.pop(context, code),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    children: [
                                      //_getCurrencyIcon(code),
                                      const SizedBox(width: 8),
                                      BBText(
                                        code,
                                        style: context.font.bodyLarge,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                if (selected != null) onCurrencyChanged(selected);
              },
              child: Image.asset(
                Assets.images2.dropdownUpdown.path,
                height: 20,
                width: 20,
              ),
            ),
          ],
        ),
        const Gap(14),
        BBText(
          '~$amountEquivalent',
          key: equivalentKey,
          style: context.font.bodyLarge,
          color: context.colour.surfaceContainer,
        ),
        const Gap(14),
        Center(
          child: Container(
            height: 40,
            width: 200,
            alignment: Alignment.center,
            child: TextField(
              onChanged: onNoteChanged,
              textAlignVertical: TextAlignVertical.center,
              textAlign: TextAlign.center,
              // expands: true,

              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: BorderSide.none,
                ),
                fillColor: context.colour.secondaryFixedDim,
                filled: true,
                // floatingLabelAlignment: FloatingLabelAlignment.center,
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
}
