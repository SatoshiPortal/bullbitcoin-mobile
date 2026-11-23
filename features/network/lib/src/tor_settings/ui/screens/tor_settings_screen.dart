import '../../../network_l10n.dart';
import '../../public/tor_settings_panel.dart';

import 'package:material_ui/material_ui.dart';

class TorSettingsScreen extends StatelessWidget {
  const TorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.torSettingsTitle)),
      body: const SafeArea(child: TorSettingsPanel()),
    );
  }
}
