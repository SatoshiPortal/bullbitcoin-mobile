import 'package:flutter/material.dart';
import 'package:screen_privacy/screen_privacy.dart';
import '../../l10n/context_localizations.dart';
import '../widgets/copy_input.dart';

class ViewVaultKeyPage extends StatefulWidget {
  final String vaultKey;

  const ViewVaultKeyPage({super.key, required this.vaultKey});

  @override
  State<ViewVaultKeyPage> createState() => _ViewVaultKeyPageState();
}

/// Shows the raw vault key, so screen capture stays blocked while mounted.
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
