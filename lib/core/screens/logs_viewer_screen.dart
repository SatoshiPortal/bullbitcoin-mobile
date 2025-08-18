import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogsViewerScreen extends StatelessWidget {
  const LogsViewerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sessionLogs = log.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Session logs')),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(sessionLogs.length, (index) {
              final logLine = sessionLogs[index];

              return Row(
                children: [
                  IconButton(
                    onPressed:
                        () => Clipboard.setData(ClipboardData(text: logLine)),
                    icon: const Icon(Icons.copy),
                  ),
                  SelectableText(
                    logLine.replaceAll('\t', ' | '),
                    style: context.font.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: context.colour.onSurface,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
