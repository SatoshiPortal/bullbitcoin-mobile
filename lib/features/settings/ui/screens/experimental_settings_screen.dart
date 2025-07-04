import 'package:bb_mobile/features/experimental/scan_signed_tx/scan_signed_tx_router.dart';
import 'package:bb_mobile/ui/components/navbar/top_bar.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExperimentalSettingsScreen extends StatelessWidget {
  const ExperimentalSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: TopBar(
          title: 'Experimental / Danger Zone',
          color: context.colour.secondaryFixed,
          onBack: context.pop,
        ),
      ),
      backgroundColor: Theme.of(context).colorScheme.secondaryFixed,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Center(
            child: Column(
              children: [
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(2),
                  ),
                  tileColor: Colors.transparent,
                  title: const Text('Scan / Paste Transaction'),
                  onTap: () => context.pushNamed(ScanSignedTxRoutes.go.name),
                  trailing: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
