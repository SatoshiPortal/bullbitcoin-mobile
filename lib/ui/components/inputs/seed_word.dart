import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    focusNodes = List.generate(widget.wordCount, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
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
      itemBuilder: (context, index) {
        final int rows = (widget.wordCount / 2).ceil();
        final int col = index % 2;
        final int row = index ~/ 2;
        final int wordIndex = row + col * rows;
        return SeedWord(
          wordIndex: wordIndex,
          validWords: widget.validWords,
          hintWords: widget.hintWords,
          onWordChanged: widget.onWordChanged,
          focusNodes: focusNodes,
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
  final List<FocusNode> focusNodes;

  const SeedWord({
    required this.wordIndex,
    required this.validWords,
    required this.hintWords,
    required this.onWordChanged,
    required this.focusNodes,
  });

  @override
  State<SeedWord> createState() => SeedWordState();
}

class SeedWordState extends State<SeedWord> {
  final TextEditingController _controller = TextEditingController();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();
  final GlobalKey _textFieldKey = GlobalKey();
  bool _listenerAttached = false;

  @override
  void initState() {
    super.initState();

    _controller.addListener(() {
      final word = widget.validWords[widget.wordIndex] ?? '';
      if (word != _controller.text) {
        widget.onWordChanged((index: widget.wordIndex, word: _controller.text));
      }
    });
    _attachFocusListener();

    final wordAtIdx = widget.validWords[widget.wordIndex];

    if (wordAtIdx != null) {
      _controller.text = wordAtIdx;
    }
  }

  void _attachFocusListener() {
    if (_listenerAttached) return;
    widget.focusNodes[widget.wordIndex].addListener(_focusListener);
    _listenerAttached = true;
  }

  void _removeFocusListener() {
    if (!_listenerAttached) return;
    widget.focusNodes[widget.wordIndex].removeListener(_focusListener);
    _listenerAttached = false;
  }

  void _focusListener() {
    final hintWords = widget.hintWords[widget.wordIndex];
    if (widget.focusNodes[widget.wordIndex].hasFocus &&
        hintWords != null &&
        hintWords.isNotEmpty) {
      _showOverlay();
    } else {
      _removeOverlay();
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
    final renderBox =
        _textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    final size = renderBox?.size ?? Size.zero;

    final hintWords = widget.hintWords[widget.wordIndex] ?? [];

    return OverlayEntry(
      builder:
          (context) => Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height),
              child: Material(
                elevation: 2,
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children:
                      hintWords.map((hint) {
                        return ListTile(
                          title: BBText(hint, style: context.font.labelMedium),
                          onTap: () {
                            _controller.text = hint;
                            _removeOverlay();
                            widget.focusNodes[widget.wordIndex].nextFocus();
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
    _removeFocusListener();
    _controller.dispose();
    _removeOverlay();
    super.dispose();
  }

  String _index(int idx) {
    return idx < 10 ? '0$idx' : '$idx';
  }

  @override
  void didUpdateWidget(covariant SeedWord oldWidget) {
    if (oldWidget.focusNodes != widget.focusNodes ||
        oldWidget.wordIndex != widget.wordIndex) {
      _removeFocusListener();
      _attachFocusListener();
    }
    if (oldWidget.hintWords != widget.hintWords) {
      final hintWords = widget.hintWords[widget.wordIndex] ?? [];
      if (widget.focusNodes[widget.wordIndex].hasFocus &&
          hintWords.isNotEmpty) {
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
                  _index(widget.wordIndex + 1),
                  style: context.font.headlineMedium,
                  color: context.colour.onPrimary,
                  textAlign: TextAlign.right,
                ),
              ),
              const Gap(4),
              Expanded(
                child: TextField(
                  key: _textFieldKey,
                  controller: _controller,
                  focusNode: widget.focusNodes[widget.wordIndex],
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  onEditingComplete: () {
                    _removeOverlay();
                    final wordCount = widget.focusNodes.length;
                    final int nextWordIndex = widget.wordIndex + 1;
                    if (nextWordIndex < wordCount) {
                      FocusScope.of(
                        context,
                      ).requestFocus(widget.focusNodes[nextWordIndex]);
                    }
                  },
                  enableSuggestions: false,
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
      ),
    );
  }
}
