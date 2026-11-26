import 'package:material_ui/material_ui.dart';

/// Covers the app the moment it stops being the active window, so the app
/// switcher and screenshots of the task list show no wallet content. It is not
/// the lock: nothing is revoked here, and returning to the app removes it.
///
/// `BullScreenPrivacyGate` is a different tool: it draws a secret only once
/// screen-capture protection is confirmed and reacts to nothing in the
/// lifecycle. Whether the OS takes its preview before or after this frame is
/// platform behaviour that only a device can show.
final class AccessPrivacyVeil extends StatefulWidget {
  final Widget child;

  const AccessPrivacyVeil({super.key, required this.child});

  @override
  State<AccessPrivacyVeil> createState() => _AccessPrivacyVeilState();
}

final class _AccessPrivacyVeilState extends State<AccessPrivacyVeil>
    with WidgetsBindingObserver {
  var _covered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final covered = state != AppLifecycleState.resumed;
    if (covered != _covered) setState(() => _covered = covered);
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      ExcludeSemantics(excluding: _covered, child: widget.child),
      if (_covered)
        Positioned.fill(
          child: ColoredBox(
            key: const ValueKey('access-privacy-veil'),
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
    ],
  );
}
