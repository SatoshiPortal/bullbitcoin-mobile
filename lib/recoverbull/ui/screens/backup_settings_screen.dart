import 'package:bb_mobile/_utils/build_context_x.dart';
import 'package:flutter/material.dart';

class BackupSettingsScreen extends StatelessWidget {
  const BackupSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.loc.backupSettingsScreenTitle),
      ),
      body: SafeArea(
        child: Container(),
      ),
    );
  }
}
