import 'package:bb_mobile/features/experimental/import_watch_only_wallet/extended_public_key_entity.dart';
import 'package:bb_mobile/ui/themes/app_theme.dart';
import 'package:flutter/material.dart';

class ImportScreen extends StatefulWidget {
  final ExtendedPublicKeyEntity pub;
  const ImportScreen({super.key, required this.pub});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colour.surface,
      appBar: AppBar(
        title: const Text('Import Watch Only Wallet'),
        backgroundColor: context.colour.surface,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Extended Public Key', style: context.font.titleMedium),
          const SizedBox(height: 8),
          Text(widget.pub.key, style: context.font.bodyMedium),
          const SizedBox(height: 16),
          Text('Type', style: context.font.titleMedium),
          const SizedBox(height: 8),
          Text(widget.pub.type.name, style: context.font.bodyMedium),
          const SizedBox(height: 16),
          Text('Label', style: context.font.titleMedium),
          const SizedBox(height: 8),
          Text(
            widget.pub.label.isEmpty ? 'No label' : widget.pub.label,
            style: context.font.bodyMedium,
          ),
        ],
      ),
    );
  }
}
