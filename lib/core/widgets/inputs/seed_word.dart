import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SeedWordsGrid extends StatefulWidget {
  const SeedWordsGrid({
    super.key,
    required this.wordCount,
    required this.validWords,
    required this.hintWords,
    required this.onWordChanged,
  });

  final int wordCount;
  final Map<int, String> validWords;
  final Map<int, List<String>> hintWords;
  final Function(({int index, String word})) onWordChanged;

  @override
  State<SeedWordsGrid> createState() => _SeedWordsGridState();
}

class _SeedWordsGridState extends State<SeedWordsGrid> {
  late final List<FocusNode> focusNodes;
  late final List<int> indexOrder;
  int? _focusedDisplayIndex;

  @override
  void initState() {
    super.initState();
    indexOrder = _createIndexOrder();
    focusNodes = List.generate(
      widget.wordCount,
      (_) => FocusNode()..addListener(_handleFocusChange),
    );
  }

  void _handleFocusChange() {
    final focusedIndex = focusNodes.indexWhere((node) => node.hasFocus);
    if (_focusedDisplayIndex != focusedIndex) {
      setState(
        () => _focusedDisplayIndex = focusedIndex != -1 ? focusedIndex : null,
      );
    }
  }

  List<int> _createIndexOrder() {
    const int columns = 2;
    final int rows = widget.wordCount ~/ columns;
    return List.generate(widget.wordCount, (i) {
      final int col = i % columns;
      final int row = i ~/ columns;
      return col == 0 ? row : rows + row;
    });
  }

  @override
  void dispose() {
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _moveToNextField(int currentLogicalIndex) {
    final nextLogicalIndex = currentLogicalIndex + 1;
    if (nextLogicalIndex < widget.wordCount) {
      final nextDisplayIndex = indexOrder.indexOf(nextLogicalIndex);
      if (nextDisplayIndex >= 0 && nextDisplayIndex < focusNodes.length) {
        FocusScope.of(context).requestFocus(focusNodes[nextDisplayIndex]);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          itemCount: widget.wordCount,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 32,
            childAspectRatio: 3.5,
          ),
          itemBuilder: (context, displayIndex) {
            final logicalIndex = indexOrder[displayIndex];
            return SeedWord(
              wordIndex: logicalIndex,
              displayNumber: logicalIndex + 1,
              validWords: widget.validWords,
              onWordChanged: widget.onWordChanged,
              focusNode: focusNodes[displayIndex],
              onComplete: () => _moveToNextField(logicalIndex),
            );
          },
        ),
        const Gap(24),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child:
              (_focusedDisplayIndex != null)
                  ? _buildHintsList(key: ValueKey(_focusedDisplayIndex))
                  : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildHintsList({Key? key}) {
    final displayIndex = _focusedDisplayIndex ?? -1;
    if (displayIndex < 0) return const SizedBox.shrink();
    final logicalIndex = indexOrder[displayIndex];
    final hints = widget.hintWords[logicalIndex] ?? [];
    if (hints.isEmpty) return const SizedBox.shrink();
    return Container(
      key: key,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hints.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _HintChip(
            word: hints[index],
            onTap: () {
              widget.onWordChanged((index: logicalIndex, word: hints[index]));
              _moveToNextField(logicalIndex);
            },
          );
        },
      ),
    );
  }
}

class SeedWord extends StatefulWidget {
  final int wordIndex;
  final int displayNumber;
  final Map<int, String> validWords;
  final Function(({int index, String word})) onWordChanged;
  final FocusNode focusNode;
  final VoidCallback onComplete;

  const SeedWord({
    required this.wordIndex,
    required this.displayNumber,
    required this.validWords,
    required this.onWordChanged,
    required this.focusNode,
    required this.onComplete,
  });

  @override
  State<SeedWord> createState() => SeedWordState();
}

class SeedWordState extends State<SeedWord> {
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final word = widget.validWords[widget.wordIndex] ?? '';
      if (word != _controller.text) {
        widget.onWordChanged((index: widget.wordIndex, word: _controller.text));
      }
    });
    final wordAtIdx = widget.validWords[widget.wordIndex];
    if (wordAtIdx != null) {
      _controller.text = wordAtIdx;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _index(int idx) => idx < 10 ? '0$idx' : '$idx';

  @override
  void didUpdateWidget(covariant SeedWord oldWidget) {
    if (oldWidget.validWords != widget.validWords) {
      final wordAtIdx = widget.validWords[widget.wordIndex];
      if (wordAtIdx != null && wordAtIdx != _controller.text) {
        _controller.text = wordAtIdx;
      }
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: context.colour.secondary),
        ),
        height: 41,
        child: Row(
          children: [
            Container(
              height: 34,
              width: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colour.secondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: BBText(
                _index(widget.displayNumber),
                style: context.font.headlineMedium,
                color: context.colour.onPrimary,
                textAlign: TextAlign.right,
              ),
            ),
            const Gap(4),
            Expanded(
              child: TextField(
                enableSuggestions: false,
                autocorrect: false,
                controller: _controller,
                focusNode: widget.focusNode,
                clipBehavior: Clip.antiAliasWithSaveLayer,
                onEditingComplete: widget.onComplete,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.only(right: 8),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.transparent),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final String word;
  final VoidCallback onTap;

  const _HintChip({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          color: context.colour.onPrimary,
          border: Border.all(color: context.colour.surface),
        ),
        child: Center(child: BBText(word, style: context.font.bodyLarge)),
      ),
    );
  }
}

class HintsList extends StatelessWidget {
  const HintsList();

  @override
  Widget build(BuildContext context) {
    final gridState = context.findAncestorStateOfType<_SeedWordsGridState>();
    if (gridState == null) return const SizedBox.shrink();
    return gridState._buildHintsList();
  }
}
