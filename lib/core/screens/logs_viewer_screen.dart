import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/log_viewer_widget.dart';
import 'package:flutter/material.dart';

class LogsViewerScreen extends StatelessWidget {
  final List<String> logs;

  const LogsViewerScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.coreScreensLogsTitle)),
      body: LogsViewerWidget(logs: logs),
    );
  }
}
