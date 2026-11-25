import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;

/// Keeps the displayed network aligned with the runtime family until restart.
class AppliedNetworkBuilder extends StatefulWidget {
  const AppliedNetworkBuilder({
    required this.selected,
    required this.builder,
    super.key,
  });

  final NetworkEnv? selected;
  final Widget Function(BuildContext context, NetworkEnv? network) builder;

  @override
  State<AppliedNetworkBuilder> createState() => _AppliedNetworkBuilderState();
}

class _AppliedNetworkBuilderState extends State<AppliedNetworkBuilder> {
  NetworkEnv? _applied;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final applied = _applied;
    if (selected != null &&
        (applied == null ||
            (applied != NetworkEnv.regtest &&
                selected != NetworkEnv.regtest))) {
      _applied = selected;
    }
    return widget.builder(context, _applied);
  }
}

/// Network banners replace the beta banner, not the content underneath it.
Widget networkBanner({
  required BuildContext context,
  required NetworkEnv? network,
  required bool beta,
  required Widget child,
}) {
  final message = switch (network) {
    NetworkEnv.testnet => 'TESTNET',
    NetworkEnv.regtest => 'REGTEST',
    _ => beta ? 'BETA' : null,
  };
  if (message == null) return child;
  final banner = Banner(
    message: message,
    location: BannerLocation.topEnd,
    layoutDirection:
        network == NetworkEnv.testnet || network == NetworkEnv.regtest
        ? TextDirection.ltr
        : null,
    color: Theme.of(context).colorScheme.error,
    child: child,
  );
  if (network != NetworkEnv.testnet && network != NetworkEnv.regtest) {
    return banner;
  }
  return Semantics(container: true, label: message, child: banner);
}
