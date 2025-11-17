import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:flutter/material.dart';

class ViewVaultKeyPage extends StatelessWidget {
  final String vaultKey;

  const ViewVaultKeyPage({super.key, required this.vaultKey});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(context.loc.recoverbullVaultKey)),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: CopyInput(
                text:
                    vaultKey.length >= 6
                        ? vaultKey.substring(0, 6) + '*' * (vaultKey.length - 6)
                        : '',
                canShowValueModal: true,
                maxLines: 1,

                clipboardText: vaultKey,
                overflow: TextOverflow.clip,
                modalContent:
                    vaultKey
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
