import 'dart:async';

import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart' show BullPage, BullTopBar;

class ViewVaultKeyPage extends StatefulWidget {
  final String vaultKey;

  const ViewVaultKeyPage({super.key, required this.vaultKey});

  @override
  State<ViewVaultKeyPage> createState() => _ViewVaultKeyPageState();
}

class _ViewVaultKeyPageState extends State<ViewVaultKeyPage>
    with PrivacyScreen {
  @override
  void initState() {
    super.initState();
    unawaited(enableScreenPrivacy());
  }

  @override
  void dispose() {
    unawaited(disableScreenPrivacy());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BullPage(
      padding: EdgeInsets.zero,
      topBar: BullTopBar(
        title: context.loc.recoverbullVaultKey,
        onBack: Navigator.of(context).canPop()
            ? () => Navigator.of(context).pop()
            : null,
      ),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Semantics(
              container: true,
              label: context.loc.recoverbullVaultKey,
              child: ExcludeSemantics(
                child: CopyInput(
                  text: widget.vaultKey.length >= 6
                      ? widget.vaultKey.substring(0, 6) +
                            '*' * (widget.vaultKey.length - 6)
                      : '',
                  canShowValueModal: true,
                  maxLines: 1,
                  clipboardText: widget.vaultKey,
                  overflow: .clip,
                  modalContent: widget.vaultKey
                      .replaceAllMapped(
                        RegExp('.{1,4}'),
                        (match) => '${match.group(0)} ',
                      )
                      .trim(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
