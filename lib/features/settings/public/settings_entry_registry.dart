import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';

enum SettingsEntrySection { wallet }

final class SettingsEntryContribution {
  final String id;
  final SettingsEntrySection section;
  final String Function(AppLocalizations localization) title;
  final IconData icon;
  final void Function(BuildContext context) open;

  const SettingsEntryContribution({
    required this.id,
    required this.section,
    required this.title,
    required this.icon,
    required this.open,
  });
}

final class SettingsEntryRegistry {
  final List<SettingsEntryContribution> _entries = [];

  List<SettingsEntryContribution> get entries => List.unmodifiable(_entries);

  void register(SettingsEntryContribution contribution) {
    _entries.removeWhere((entry) => entry.id == contribution.id);
    _entries.add(contribution);
  }
}
