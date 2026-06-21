import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

/// SEALED display of a derived BIP85 hex secret. The hex is read from the
/// payload's `@internal` accessor here only.
class Bip85HexView extends StatelessWidget {
  const Bip85HexView({super.key, required this.result});

  final Bip85HexResult result;

  @override
  Widget build(BuildContext context) {
    return PrivacyGuard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(
            result.path.path,
            style: Theme.of(context).textTheme.bodyMedium,
            color: context.bull.textMuted,
          ),
          const Gap(BullSpacing.sm),
          // Non-selectable on purpose: the clipboard is a broad, persistent
          // sink PrivacyGuard cannot cover, so the derived secret is displayed
          // read-only — same stance as the mnemonic views.
          BullText(
            result.hexForView,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('path', result.path.path));
    // hex intentionally omitted.
  }
}
