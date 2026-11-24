import 'package:bull_ui/bull_ui.dart';

typedef SettingsMenu = ({List<SettingsEntry> entries, String? appVersion});

typedef SettingsLabels = ({
  String title,
  String searchHint,
  String searchStartTyping,
  String searchNoResults,
  String appVersionLabel,
});

final class SettingsEntry {
  final String id;
  final String title;
  final List<String> breadcrumbs;
  final IconData icon;
  final void Function(BuildContext) open;
  final List<String> keywords;
  final bool showOnHome;
  final bool isSuperuser;
  final bool indicatesServiceHealth;
  final Widget? homeIcon;

  const SettingsEntry({
    required this.id,
    required this.title,
    required this.breadcrumbs,
    required this.icon,
    required this.open,
    this.keywords = const [],
    this.showOnHome = false,
    this.isSuperuser = false,
    this.indicatesServiceHealth = false,
    this.homeIcon,
  });
}
