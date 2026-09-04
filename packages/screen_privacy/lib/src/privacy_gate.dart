import 'package:flutter/material.dart';

/// Renders [builder] only once [protection] has completed successfully.
///
/// `FutureBuilder` calls its builder while the future is still pending, so a
/// secret handed to it directly is on screen before the OS capture flag is
/// set. This widget shows a spinner until then, and if protection could not
/// be enabled it shows [unprotected] and never builds the secret at all.
class PrivacyGate extends StatelessWidget {
  final Future<void> protection;
  final WidgetBuilder builder;
  final Widget unprotected;

  const PrivacyGate({
    super.key,
    required this.protection,
    required this.builder,
    required this.unprotected,
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: protection,
    builder: (context, snapshot) {
      if (snapshot.hasError) return unprotected;
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return builder(context);
    },
  );
}
