import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bb_mobile/ui/components/buttons/button.dart';
import 'package:bb_mobile/ui/components/text/text.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class RecoverPhysicalWalletSuccessScreen extends StatelessWidget {
  const RecoverPhysicalWalletSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const Spacer(),
            Column(
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Gif(
                    image: AssetImage(Assets.images2.successTick.path),
                    autostart: Autostart.once,
                    height: 200,
                    width: 200,
                  ),
                ),
                const Gap(8),
                BBText(
                  'Wallet imported successfully',
                  style: context.font.headlineLarge,
                ),
              ],
            ),
            const Spacer(flex: 2),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: BBButton.big(
                label: 'Got it',
                bgColor: context.colour.secondary,
                textColor: context.colour.onPrimary,
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
