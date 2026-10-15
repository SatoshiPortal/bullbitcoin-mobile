import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';

class ViewVaultKeyPage extends StatefulWidget {
  final String vaultKey;

  const ViewVaultKeyPage({super.key, required this.vaultKey});

  @override
  State<ViewVaultKeyPage> createState() => _ViewVaultKeyPageState();
}

// The vault key decrypts the backup, so the page blocks screen capture like
// the mnemonic screens, and a copied key does not stay on the clipboard.
class _ViewVaultKeyPageState extends State<ViewVaultKeyPage>
    with PrivacyScreen {
  @override
  void initState() {
    super.initState();
    enableScreenPrivacy();
  }

  @override
  void dispose() {
    disableScreenPrivacy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vaultKey = widget.vaultKey;
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.recoverbullVaultKey)),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: .center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: CopyInput(
                text: vaultKey.length >= 6
                    ? vaultKey.substring(0, 6) + '*' * (vaultKey.length - 6)
                    : '',
                canShowValueModal: true,
                maxLines: 1,

                clipboardText: vaultKey,
                clearClipboardAfter: const Duration(seconds: 30),
                secret: true,
                overflow: .clip,
                modalContent: vaultKey
                    .replaceAllMapped(
                      RegExp('.{1,4}'),
                      (match) => '${match.group(0)} ',
                    )
                    .trim(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
