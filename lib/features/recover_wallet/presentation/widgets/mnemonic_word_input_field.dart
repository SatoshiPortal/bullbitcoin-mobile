import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MnemonicWordInputField extends StatefulWidget {
  final int wordIndex;

  const MnemonicWordInputField({required this.wordIndex});

  @override
  State<MnemonicWordInputField> createState() => MnemonicWordInputFieldState();
}

class MnemonicWordInputFieldState extends State<MnemonicWordInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void initState() {
    super.initState();

    _controller.addListener(
      () {
        final word = context
                .read<RecoverWalletBloc>()
                .state
                .validWords[widget.wordIndex] ??
            '';
        if (word != _controller.text) {
          context.read<RecoverWalletBloc>().add(
                RecoverWalletWordChanged(
                  index: widget.wordIndex,
                  word: _controller.text,
                ),
              );
        }
      },
    );
    _focusNode.addListener(
      () {
        final hintWords =
            context.read<RecoverWalletBloc>().state.hintWords[widget.wordIndex];
        if (_focusNode.hasFocus && hintWords != null && hintWords.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      },
    );
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
    final hintWords =
        context.read<RecoverWalletBloc>().state.hintWords[widget.wordIndex] ??
            [];

    return OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width * 0.4,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 4,
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<RecoverWalletBloc, RecoverWalletState>(
      listenWhen: (previous, current) =>
          previous.hintWords[widget.wordIndex] !=
          current.hintWords[widget.wordIndex],
      listener: (context, state) {
        final hintWords = state.hintWords[widget.wordIndex] ?? [];
        if (_focusNode.hasFocus && hintWords.isNotEmpty) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          onEditingComplete: _removeOverlay,
        ),
      ),
    );
  }
}
