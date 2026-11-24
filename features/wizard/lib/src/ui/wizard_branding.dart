import 'package:flutter/widgets.dart';

/// Brand images shared with the host's other flows.
final class WizardBranding {
  final ImageProvider headerLogo;
  final ImageProvider welcomeLogo;
  final ImageProvider welcomePattern;

  const WizardBranding({
    required this.headerLogo,
    required this.welcomeLogo,
    required this.welcomePattern,
  });
}
