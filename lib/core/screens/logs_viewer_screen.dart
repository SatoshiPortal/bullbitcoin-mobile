import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LogsViewerScreen extends StatelessWidget {
  final List<String> logs;

  const LogsViewerScreen({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session logs')),
      body: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(logs.length, (index) {
              final logLine = logs.reversed.toList()[index];

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
