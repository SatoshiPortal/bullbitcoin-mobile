import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExchangeLegacyTransactionsScreen extends StatelessWidget {
  const ExchangeLegacyTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.surface,
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Legacy Transactions',
          onBack: () => context.pop(),
        ),
      ),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: Text('Legacy Transactions - Coming Soon')),
        ),
      ),
    );
  }
}
