import 'package:bb_mobile/core/mempool/application/dtos/mempool_server_dto.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DefaultServerCard extends StatelessWidget {
  final MempoolServerDto server;

  const DefaultServerCard({
    super.key,
    required this.server,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    server.url,
                    style: context.font.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    server.fullUrl,
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: server.url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('URL copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
