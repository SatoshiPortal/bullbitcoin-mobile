import 'package:bull_ui/src/data_display/bull_text.dart';
import 'package:bull_ui/src/theme/bull_theme.dart';
import 'package:bull_ui/src/theme/bull_tokens.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

/// A single numbered mnemonic word cell. **Dumb / presentational** — it knows
/// nothing about seeds; the caller supplies the [number] and [word]. Domain
/// packages (e.g. `secrets`) compose it inside a sealed widget.
class BullMnemonicWord extends StatelessWidget {
  const BullMnemonicWord({
    super.key,
    required this.number,
    required this.word,
  });

  final int number;
  final String word;

  @override
  Widget build(BuildContext context) {
    final colors = context.bull;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: BullSpacing.sm, vertical: BullSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(BullRadius.sm),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          // minWidth (not a fixed width) keeps single-digit indices aligned
          // while letting 2-digit indices (10–24) grow at large text scale
          // instead of clipping.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: BullText(
              '$number',
              style: Theme.of(context).textTheme.bodyMedium,
              color: colors.textMuted,
            ),
          ),
          const Gap(BullSpacing.xs),
          Expanded(
            child: BullText(
              word,
              style: Theme.of(context).textTheme.bodyLarge,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// A two-column numbered grid of mnemonic words. **Dumb / presentational.**
class BullMnemonicGrid extends StatelessWidget {
  const BullMnemonicGrid({super.key, required this.words});

  final List<String> words;

  @override
  Widget build(BuildContext context) {
    final half = (words.length + 1) ~/ 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < half; i++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: BullMnemonicWord(number: i + 1, word: words[i]),
              ),
              const Gap(BullSpacing.sm),
              Expanded(
                child: i + half < words.length
                    ? BullMnemonicWord(
                        number: i + half + 1, word: words[i + half])
                    : const SizedBox(),
              ),
            ],
          ),
          const Gap(BullSpacing.sm),
        ],
      ],
    );
  }
}
