import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton, BullSuccessScreen;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gif/gif.dart';
import 'package:go_router/go_router.dart';

class TestCompletedPage extends StatelessWidget {
  const TestCompletedPage({super.key});

  /// Refreshes the wallet's backup status so the home backup warning clears,
  /// then leaves the test flow for the wallet home.
  void _done(BuildContext context) {
    context.read<WalletBloc>().add(const VerifyBackupStatus());
    context.goNamed(WalletRoute.walletHome.name);
  }

  @override
  Widget build(BuildContext context) {
    return BullSuccessScreen(
      title: context.loc.backupSettingsTestBackup,
      headline: context.loc.recoverbullTestCompletedTitle,
      onClose: () => _done(context),
      showCloseButton: false,
      backgroundColor: context.appColors.background,
      headlineStyle: context.font.headlineLarge,
      icon: Gif(
        image: AssetImage(Assets.animations.successTick.path),
        autostart: Autostart.once,
        height: 200,
        width: 200,
      ),
      message: Text(context.loc.recoverbullTestSuccessDescription),
      actions: [
        BullButton.big(
          label: context.loc.recoverbullGotIt,
          onPressed: () => _done(context),
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }
}
