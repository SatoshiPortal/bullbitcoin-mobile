import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/logger.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class LoggerPage extends StatelessWidget {
  const LoggerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final logs =
        context.select((Logger logger) => logger.state.reversed.toList());

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: BBAppBar(
          text: 'Logs',
          onBack: () {
            context.pop();
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (logs.isEmpty)
              const Center(child: BBText.titleLarge('No logs'))
            else ...[
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        context.read<Logger>().shareLog();
                      },
                      child: const BBText.bodySmall('Share logs'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<Logger>().clear();
                      },
                      child: const BBText.bodySmall('Clear'),
                    ),
                  ],
                ),
              ),
              const Divider(),
            ],
            for (final log in logs) _LogItem(log: log),
          ],
        ),
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  const _LogItem({required this.log});

  final (String, DateTime) log;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: BBText.bodySmall(log.$1),
      subtitle: BBText.bodySmall(log.$2.toString(), isBold: true),
      onLongPress: () {
        if (locator.isRegistered<Clippboard>()) {
          locator<Clippboard>().copy(log.$1);
        }

        // ScaffoldMessenger.of(context)
        //     .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
      },
    );
  }
}
