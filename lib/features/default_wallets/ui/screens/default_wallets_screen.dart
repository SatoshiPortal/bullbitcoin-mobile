import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/default_wallets/ui/widgets/default_wallets_editor.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bull_ui/bull_ui.dart' show BullTopBar;

class DefaultWalletsScreen extends StatelessWidget {
  const DefaultWalletsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          title: context.loc.exchangeBitcoinWalletsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: const DefaultWalletsEditor(),
    );
  }
}
