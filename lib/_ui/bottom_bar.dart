import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';

class BottomBar extends StatelessWidget {
  const BottomBar({
    super.key,
    required this.pageChanged,
    required this.pageIdx,
    this.pages = const ['Wallet', 'Market'],
  });

  final Function(int) pageChanged;
  final int pageIdx;
  final List<String> pages;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.colour.onPrimaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < pages.length; i++)
            TextButton(
              onPressed: () {
                pageChanged(i);
              },
              style: TextButton.styleFrom(
                foregroundColor: pageIdx == i
                    ? context.colour.onPrimary
                    : context.colour.onPrimary.withOpacity(0.5),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: BBText.title(
                pages[i],
                onSurface: true,
                isBold: true,
              ),
            ),
        ],
      ),
    );
  }
}
