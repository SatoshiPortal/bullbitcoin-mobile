import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/material.dart';

/// What a secret-bearing screen shows instead of the secret when screen
/// capture protection could not be turned on.
class PrivacyUnavailableNotice extends StatelessWidget {
  /// Whether this fills the whole route (own app bar with a back button) or
  /// sits inside a screen that already has one.
  final bool standalone;

  const PrivacyUnavailableNotice({super.key, this.standalone = true});

  @override
  Widget build(BuildContext context) {
    final body = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          context.loc.screenPrivacyUnavailable,
          textAlign: TextAlign.center,
          style: context.font.bodyLarge,
        ),
      ),
    );
    if (!standalone) return body;
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(),
      body: SafeArea(child: body),
    );
  }
}
