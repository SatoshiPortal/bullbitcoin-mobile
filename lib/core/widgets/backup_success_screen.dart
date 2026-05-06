import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class BackupSuccessScreen extends StatelessWidget {
  const BackupSuccessScreen({
    super.key,
    required this.title,
    required this.message,
    required this.buttonLabel,
  });

  final String title;
  final String message;
  final String buttonLabel;

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
                BBText(title, style: context.font.headlineLarge),
                const Gap(8),
                BBText(
                  message,
                  style: context.font.bodyMedium,
                  textAlign: .center,
                ),
              ],
            ),
            const Spacer(flex: 2),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.05,
              ),
              child: BBButton.big(
                label: buttonLabel,
                bgColor: context.appColors.secondary,
                textColor: context.appColors.onSecondary,
                onPressed: () {
                  context.read<WalletBloc>().add(const VerifyBackupStatus());
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
