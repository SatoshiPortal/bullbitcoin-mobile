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
    this.error,
  });

  final String amount;
  final String currency;
  final String amountEquivalent;
  final List<String> availableCurrencies;
  final Function(String) onCurrencyChanged;
  final Function(String) onNoteChanged;
  final String? error;

  Future<String?> _openPopup(
    BuildContext context,
    String selected,
  ) async {
    final c = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colour.secondaryFixedDim,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(16),
            Row(
              // crossAxisAlignment: CrossAxisAlignment.end,
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 40,
                  ),
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
                        color: selected == curr
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
      },
    );

    return c;
  }

  @override
  Widget build(BuildContext context) {
    // Needed to position the currency dropdown underneat it.
    final equivalentKey = GlobalKey();

    return Column(
      children: [
        // if (error != null) ...[
        // Padding(
        // padding: const EdgeInsets.only(bottom: 8),
        BBText(
          error ?? '',
          style: context.font.bodyLarge,
          color: error != null ? context.colour.error : Colors.transparent,
          maxLines: 2,
        ),
        // ),
        // ],
        const Gap(8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Gap(24),
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
                // final renderBox = equivalentKey.currentContext!
                //     .findRenderObject()! as RenderBox;
                // final offset = renderBox.localToGlobal(Offset.zero) / 3;
                // final size = renderBox.size;
                // final screenWidth = MediaQuery.of(context).size.width;
                // const menuWidth = 148.0;

                // final left = screenWidth / 2 - menuWidth / 2;

                // final selected = await showMenu<String>(
                //   context: context,
                //   color: context.colour.onPrimary,
                //   position: RelativeRect.fromLTRB(
                //     left,
                //     offset.dy + size.height + 8,
                //     left,
                //     0,
                //   ),
                //   items: [
                //     PopupMenuItem<String>(
                //       enabled: false,
                //       padding: EdgeInsets.zero,
                //       child: SizedBox(
                //         height: 138,
                //         width: menuWidth, // Match your design
                //         child: Scrollbar(
                //           child: ListView.builder(
                //             padding: EdgeInsets.zero,
                //             itemCount: availableCurrencies.length,
                //             itemBuilder: (context, index) {
                //               final code = availableCurrencies[index];
                //               return InkWell(
                //                 onTap: () => Navigator.pop(context, code),
                //                 child: Padding(
                //                   padding: const EdgeInsets.symmetric(
                //                     vertical: 12,
                //                     horizontal: 16,
                //                   ),
                //                   child: Row(
                //                     children: [
                //                       //_getCurrencyIcon(code),
                //                       const SizedBox(width: 8),
                //                       BBText(
                //                         code,
                //                         style: context.font.bodyLarge,
                //                       ),
                //                     ],
                //                   ),
                //                 ),
                //               );
                //             },
                //           ),
                //         ),
                //       ),
                //     ),
                //   ],
                // );

                final selected = await _openPopup(context, currency);
                if (selected != null) onCurrencyChanged(selected);
              },
              child: Icon(
                Icons.arrow_drop_down,
                color: context.colour.secondary,
                size: 40,
              ),
              // Image.asset(
              //   Assets.images2.dropdownUpdown.path,
              //   height: 20,
              //   width: 20,
              // ),
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
            height: 50,
            width: 200,
            alignment: Alignment.center,
            child: TextField(
              onChanged: onNoteChanged,
              textAlignVertical: TextAlignVertical.center,
              textAlign: TextAlign.center,
              // expands: true,
              // maxLines: 5,
              // minLines: 1,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(2),
                  borderSide: BorderSide.none,
                  // borderSide: BorderSide(
                  //   color: context.colour.outline,
                  // ),
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

      case 'sats':
      case 'BTC':
      default:
        return '₿';
    }
  }
}
