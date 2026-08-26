import 'package:bb_mobile/features/tor_settings/ui/widgets/tor_proxy_widget.dart';
import 'package:flutter/material.dart';

/// Reusable Tor configuration owned by the Tor feature.
///
/// Consumers embed this panel through the public surface instead of importing
/// Tor presentation internals.
class TorSettingsPanel extends StatelessWidget {
  final EdgeInsetsGeometry padding;

  const TorSettingsPanel({this.padding = const EdgeInsets.all(16), super.key});

  @override
  Widget build(BuildContext context) =>
      SingleChildScrollView(padding: padding, child: const TorProxyWidget());
}
