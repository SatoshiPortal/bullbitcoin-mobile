import 'package:bb_mobile/core_deprecated/themes/app_theme.dart';
import 'package:bb_mobile/core_deprecated/utils/build_context_x.dart';
import 'package:bb_mobile/core_deprecated/widgets/buttons/button.dart';
import 'package:bb_mobile/core_deprecated/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class BackupTestSuccessScreen extends StatelessWidget {
  const BackupTestSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: <Widget>[
            const Spacer(),
            Column(
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Gif(
                    image: AssetImage(Assets.animations.successTick.path),
                    autostart: Autostart.once,
                    height: 200,
                    width: 200,
                  ),
                ),
                const Gap(8),
                BBText(
                  context.loc.testBackupSuccessTitle,
                  style: context.font.headlineLarge,
                ),
                const Gap(8),
                BBText(
                  context.loc.testBackupSuccessMessage,
                  style: context.font.bodyMedium,
                  textAlign: .center,
                ),
              ],
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: BBButton.big(
                label: context.loc.testBackupSuccessButton,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onPrimary,
                onPressed: () {
                  context.goNamed(WalletRoute.walletHome.name);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
