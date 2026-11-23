import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';

/// The settings search entry point: a rounded bar at the top of the list.
///
/// It is a button, not a field: tapping it opens the search screen instead of
/// raising a keyboard here. See [BullSearchBar.button].
class SettingsSearchBar extends StatelessWidget {
  final VoidCallback onTap;

  const SettingsSearchBar({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) =>
      BullSearchBar.button(label: context.loc.settingsSearchHint, onTap: onTap);
}
