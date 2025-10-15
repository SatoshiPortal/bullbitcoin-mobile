import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/log_viewer_widget.dart';
import 'package:flutter/material.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FutureBuilder<List<String>>(
            future: log.readLogs(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error loading logs: ${snapshot.error}'),
                );
              }

              final logs = snapshot.data ?? [];
              return LogsViewerWidget(logs: logs);
            },
          ),
        ),
      ),
    );
  }
}
