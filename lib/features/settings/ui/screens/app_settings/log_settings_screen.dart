import 'package:bb_mobile/core/widgets/share_logs_widget.dart';
import 'package:flutter/material.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ShareLogsWidget(migrationLogs: true, sessionLogs: true),
        ),
      ),
    );
  }
}
