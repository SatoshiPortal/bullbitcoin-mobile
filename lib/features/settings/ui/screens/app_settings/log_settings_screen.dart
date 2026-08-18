import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/widgets/log_viewer_widget.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class LogSettingsScreen extends StatelessWidget {
  const LogSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BullPage(
      topBar: BullTopBar(
        title: context.loc.logSettingsLogsTitle,
        onBack: context.pop,
      ),
      padding: const EdgeInsets.symmetric(horizontal: BullSpacing.md),
      child: FutureBuilder<List<String>>(
        future: log.readLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${context.loc.logSettingsErrorLoadingMessage}${snapshot.error}',
              ),
            );
          }

          final logs = snapshot.data ?? [];
          return LogsViewerWidget(logs: logs);
        },
      ),
    );
  }
}
