import 'package:bb_mobile/features/settings/ui/settings_item.dart';
import 'package:flutter/material.dart';

/// The existing labels and transaction export destinations, shared by backup pages.
class BackupDataExportEntries extends StatelessWidget {
  const BackupDataExportEntries({super.key});
  @override
  Widget build(BuildContext context) {
    final items = settingsItemsOf(context);
    return Column(
      children: [
        for (final id in backupSettingsDataItemOrder)
          items.byId(id).buildTile(context),
      ],
    );
  }
}
