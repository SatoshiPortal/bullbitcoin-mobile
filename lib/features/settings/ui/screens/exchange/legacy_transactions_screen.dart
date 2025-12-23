import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeLegacyTransactionsScreen extends StatelessWidget {
  const ExchangeLegacyTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.surfaceFixed,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: context.loc.exchangeLegacyTransactionsTitle,
          onBack: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(context.loc.exchangeLegacyTransactionsComingSoon),
          ),
        ),
      ),
    );
  }
}
