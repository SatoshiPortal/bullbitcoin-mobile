import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

class SeedWordsGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
      ),
      physics:
          const NeverScrollableScrollPhysics(), // Prevent GridView from scrolling
      shrinkWrap: true, // Allow GridView to take the height it needs
      itemCount: wordCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 32,
        childAspectRatio: 3.5,
      ),

      itemBuilder: (context, index) {
        return SeedWord(
          wordIndex: index,
          validWords: validWords,
          hintWords: hintWords,
          onWordChanged: onWordChanged,
        );
      },
    );
  }
}

class SeedWord extends StatefulWidget {
  final int wordIndex;
  final Map<int, String> validWords;
  final Map<int, List<String>> hintWords;
  final Function(({int index, String word})) onWordChanged;

  const SeedWord({
    required this.wordIndex,
    required this.validWords,
    required this.hintWords,
    required this.onWordChanged,
  });

  @override
  State<SeedWord> createState() => SeedWordState();
}

class SeedWordState extends State<SeedWord> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();

    _controller.addListener(
      () {
        final word = widget.validWords[widget.wordIndex] ?? '';
        if (word != _controller.text) {
          widget.onWordChanged(
            (
              index: widget.wordIndex,
              word: _controller.text,
            ),
          );
        }
      },
    );
    _focusNode.addListener(
      () {
        final hintWords = widget.hintWords[widget.wordIndex];
        if (_focusNode.hasFocus && hintWords != null && hintWords.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      },
    );

    final wordAtIdx = widget.validWords[widget.wordIndex];

    if (wordAtIdx != null) {
      _controller.text = wordAtIdx;
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
    }

    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject()! as RenderBox;
    final size = renderBox.size;
    // final offset = renderBox.localToGlobal(Offset.zero);

    final hintWords = widget.hintWords[widget.wordIndex] ?? [];

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 24,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(24, size.height),
          child: Material(
            elevation: 2,
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: hintWords.map((hint) {
                return ListTile(
                  title: Text(hint),
                  onTap: () {
                    _controller.text = hint;
                    _removeOverlay();
                    _focusNode.nextFocus();
                  },
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  String _index(int idx) {
    return idx < 10 ? '0$idx' : '$idx';
  }

  @override
  void didUpdateWidget(covariant SeedWord oldWidget) {
    if (oldWidget.hintWords != widget.hintWords) {
      final hintWords = widget.hintWords[widget.wordIndex] ?? [];
      if (_focusNode.hasFocus && hintWords.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 200)).then((value) {
          _showOverlay();
        });
      } else {
        _removeOverlay();
      }
    }

    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: context.colour.secondary,
            ),
          ),
          height: 41,
          child: Row(
            children: [
              Container(
                height: 34,
                width: 34,
                alignment: Alignment.center,
                // padding: const EdgeInsets.symmetric(
                //   vertical: 8,
                //   horizontal: 8,
                // ),
                decoration: BoxDecoration(
                  color: context.colour.secondary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: BBText(
                  _index(widget.wordIndex + 1),
                  style: context.font.headlineMedium,
                  color: context.colour.onPrimary,
                  textAlign: TextAlign.right,
                ),
              ),
              const Gap(4),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  onEditingComplete: _removeOverlay,
                  enableSuggestions: false,
                  decoration: const InputDecoration(
                    // fillColor: context.colour.onPrimary,
                    // filled: true,
                    contentPadding: EdgeInsets.only(
                      right: 8,
                      // vertical: 12,
                      // horizontal: 10,
                    ),
                    border: OutlineInputBorder(
                      // borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: Colors.transparent,
                        // color: context.colour.secondary,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      // borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: Colors.transparent,
                        // color: context.colour.secondary,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      // borderRadius: BorderRadius.circular(4),
                      borderSide: BorderSide(
                        color: Colors.transparent,
                        // color: context.colour.secondary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
