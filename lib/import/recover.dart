import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/page_template.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/import/bloc/words_cubit.dart';
import 'package:bb_mobile/import/page.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class ImportEnterWordsScreen extends StatefulWidget {
  const ImportEnterWordsScreen({super.key});

  @override
  State<ImportEnterWordsScreen> createState() => _ImportEnterWordsScreenState();
}

class _ImportEnterWordsScreenState extends State<ImportEnterWordsScreen> {
  List<FocusNode> focusNodes = [];

  @override
  void initState() {
    super.initState();
  }

  void createFocusNodes(bool is12) {
    if (is12 && focusNodes.length == 12) return;
    if (!is12 && focusNodes.length == 24) return;

    focusNodes = List<FocusNode>.generate(
      is12 ? 12 : 24,
      (index) => FocusNode(),
    );
    setState(() {});
  }

  void returnClicked(int idx, ImportTypes importType) {
    if (importType == ImportTypes.words12 && idx == 11) return;
    if (importType == ImportTypes.words24 && idx == 23) return;
    focusNodes[idx + 1].requestFocus();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final importType =
        context.select((ImportWalletCubit cubit) => cubit.state.importType);

    createFocusNodes(importType == ImportTypes.words12);

    return StackedPage(
      bottomChild: const _ImportWordsRecoverButton(),
      child: BlocProvider.value(
        value: ScrollCubit(),
        child: Builder(
          builder: (context) {
            return SingleChildScrollView(
              controller: context.read<ScrollCubit>().state,
              key: UIKeys.importRecoverScrollable,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(22),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: SegmentedButton(
                        style: ButtonStyle(
                          iconColor: WidgetStatePropertyAll<Color>(
                            context.colour.onPrimaryContainer,
                          ),
                          backgroundColor: WidgetStatePropertyAll<Color>(
                            context.colour.primaryContainer,
                          ),
                        ),
                        segments: <ButtonSegment<ImportTypes>>[
                          ButtonSegment(
                            value: ImportTypes.words12,
                            label: Text(
                              '12 words',
                              style: TextStyle(
                                color: context.colour.onPrimaryContainer,
                              ),
                            ),
                          ),
                          ButtonSegment(
                            value: ImportTypes.words24,
                            label: Text(
                              '24 words',
                              style: TextStyle(
                                color: context.colour.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ],
                        selected: {
                          importType,
                        },
                        onSelectionChanged: (value) {
                          if (value.first == ImportTypes.words12) {
                            context.read<ImportWalletCubit>().recoverClicked();
                          }

                          if (value.first == ImportTypes.words24) {
                            context
                                .read<ImportWalletCubit>()
                                .recoverClicked24();
                          }
                        },
                      ),
                    ),
                    const Gap(25),
                    if (importType == ImportTypes.words12) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                for (var i = 0; i < 6; i++)
                                  ImportWordTextField(
                                    uiKey: UIKeys.importRecoverField(i),
                                    index: i,
                                    focusNode: focusNodes[i],
                                    returnClicked: (i) =>
                                        returnClicked(i, importType),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                for (var i = 6; i < 12; i++)
                                  ImportWordTextField(
                                    uiKey: UIKeys.importRecoverField(i),
                                    index: i,
                                    focusNode: focusNodes[i],
                                    returnClicked: (i) =>
                                        returnClicked(i, importType),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (importType == ImportTypes.words24) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                for (var i = 0; i < 12; i++)
                                  ImportWordTextField(
                                    uiKey: UIKeys.importRecoverField(i),
                                    index: i,
                                    focusNode: focusNodes[i],
                                    returnClicked: (i) =>
                                        returnClicked(i, importType),
                                  ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                for (var i = 12; i < 24; i++)
                                  ImportWordTextField(
                                    uiKey: UIKeys.importRecoverField(i),
                                    index: i,
                                    focusNode: focusNodes[i],
                                    returnClicked: (i) =>
                                        returnClicked(i, importType),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const Gap(32),
                    const _ImportWordsPassphrase(),
                    const Gap(8),
                    const WalletLabel(),
                    const Gap(8),
                    // const _ImportPikachuButton(),
                    // const Gap(8),
                    // const _ImportVegetaButton(),
                    // const Gap(8),
                    // const _ImportNarutoButton(),
                    // const Gap(8),
                    // const _ImportbdkWalletButton(),
                    const Gap(80),
                  ],
                ),
              ),
            ).animate(delay: 200.ms).fadeIn();
          },
        ),
      ),
    );
  }
}

class ImportWordTextField extends StatefulWidget {
  const ImportWordTextField({
    this.uiKey,
    required this.index,
    required this.focusNode,
    required this.returnClicked,
  });

  final Key? uiKey;

  final int index;
  final FocusNode focusNode;
  final Function(int) returnClicked;

  @override
  State<ImportWordTextField> createState() => _ImportWordTextFieldState();
}

class _ImportWordTextFieldState extends State<ImportWordTextField> {
  OverlayEntry? entry;
  final layerLink = LayerLink();
  final controller = TextEditingController();
  List<String> suggestions = [];
  bool tapped = false;

  @override
  void initState() {
    super.initState();

    widget.focusNode.addListener(() {
      if (widget.focusNode.hasFocus) {
        showOverLay();
      } else {
        hideOverlay();
      }
    });

    controller.addListener(() {
      hideOverlay();
      setState(() {
        suggestions =
            context.read<WordsCubit>().state.findWords(controller.text);
      });
      if (tapped) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showOverLay();
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    widget.focusNode.dispose();

    super.dispose();
  }

  void showOverLay() {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject()! as RenderBox;
    final size = renderBox.size;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width - 24,
        child: CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: Offset(24, size.height - 8),
          child: buildOverlay(),
        ),
      ),
    );

    overlay.insert(entry!);
  }

  void hideOverlay() {
    entry?.remove();
    entry = null;
  }

  bool checkFirstSuggestionWord(String word) {
    return suggestions.isNotEmpty && suggestions.first == word;
  }

  Widget buildOverlay() {
    if (suggestions.isEmpty) {
      hideOverlay();
      return Container();
    }

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(8),
      shadowColor: Colors.white,
      child: Column(
        children: [
          for (int i = 0; i < suggestions.length; i++)
            ListTile(
              tileColor: context.colour.primaryContainer,
              key: i == 0 ? UIKeys.firstSuggestionWord : null,
              title: BBText.body(suggestions[i]),
              onTap: () {
                context
                    .read<ImportWalletCubit>()
                    .wordChanged(widget.index, suggestions[i], true);
                hideOverlay();
                setState(() {
                  tapped = true;
                });
                widget.focusNode.unfocus();
                widget.returnClicked(widget.index);
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final is12 =
        context.select((ImportWalletCubit cubit) => cubit.state.is12());

    final word = context.select(
      (ImportWalletCubit cubit) => is12
          ? cubit.state.words12.elementAtOrNull(widget.index)
          : cubit.state.words24.elementAtOrNull(widget.index),
    );

    if (word == null) return const SizedBox.shrink();
    if (controller.text != word.word) controller.text = word.word;

    return CompositedTransformTarget(
      link: layerLink,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        height: 45,
        child: Row(
          children: [
            SizedBox(
              width: 25,
              child: BBText.body(
                '${widget.index + 1}',
                textAlign: TextAlign.right,
              ),
            ),
            const Gap(5),
            Expanded(
              child: CallbackShortcuts(
                bindings: {
                  LogicalKeySet(LogicalKeyboardKey.enter): () {
                    if (widget.focusNode.hasFocus) {
                      widget.returnClicked(widget.index);
                    }
                  },
                },
                child: AnimatedOpacity(
                  duration: 200.ms,
                  opacity: !word.tapped ? 0.5 : 1,
                  child: BBTextInput.small(
                    uiKey: widget.uiKey,
                    focusNode: widget.focusNode,
                    controller: controller,
                    onDone: (value) {
                      if (suggestions.isEmpty) return;
                      final firstSuggestion = suggestions.first;
                      context
                          .read<ImportWalletCubit>()
                          .wordChanged(widget.index, firstSuggestion, true);

                      setState(() {
                        tapped = true;
                      });
                      widget.focusNode.unfocus();
                      widget.returnClicked(widget.index);
                      hideOverlay();
                    },
                    onEnter: () {
                      context.read<ImportWalletCubit>().clearUntappedWords();
                    },
                    onChanged: (value) {
                      context
                          .read<ImportWalletCubit>()
                          .wordChanged(widget.index, value, false);
                      hideOverlay();

                      setState(() {
                        tapped = false;
                      });
                    },
                    value: word.word,
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

class _ImportWordsPassphrase extends StatelessWidget {
  const _ImportWordsPassphrase();

  @override
  Widget build(BuildContext context) {
    final text =
        context.select((ImportWalletCubit cubit) => cubit.state.passPhrase);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: BBTextInput.big(
        value: text,
        onChanged: (value) =>
            context.read<ImportWalletCubit>().passPhraseChanged(value),
        hint: 'Enter passphrase if needed',
      ),
    );
  }
}

class _ImportWordsRecoverButton extends StatelessWidget {
  const _ImportWordsRecoverButton();

  @override
  Widget build(BuildContext context) {
    final recovering =
        context.select((ImportWalletCubit cubit) => cubit.state.importing);
    final err =
        context.select((ImportWalletCubit cubit) => cubit.state.errImporting);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (err.isNotEmpty) ...[
          // const Gap(8),
          BBText.errorSmall(err),
        ],
        Center(
          child: BBButton.big(
            buttonKey: UIKeys.importRecoverConfirmButton,
            label: 'Recover',
            onPressed: () {
              context.read<ImportWalletCubit>().recoverWalletClicked();
            },
            disabled: recovering,
          ),
        ),
      ],
    );
  }
}
