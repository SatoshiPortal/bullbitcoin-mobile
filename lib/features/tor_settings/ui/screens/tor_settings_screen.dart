import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_proxy_widget.dart';
import 'package:flutter/material.dart';

class TorSettingsScreen extends StatelessWidget {
  const TorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.loc.torSettingsTitle)),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: .stretch,
            children: [TorProxyWidget()],
          ),
        ),
      ),
    );
  }
}
