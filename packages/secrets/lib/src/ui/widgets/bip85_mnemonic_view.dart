import 'package:bull_ui/bull_ui.dart';
import 'package:secrets/src/domain/value_objects/bip85_types.dart';
import 'package:secrets/src/ui/privacy_guard.dart';

/// SEALED display of a derived BIP85 child mnemonic. The words travel inside the
/// [Bip85Derivation] payload (an `@internal` field) and are read here only —
/// never exposed through a public getter.
class Bip85MnemonicView extends StatelessWidget {
  const Bip85MnemonicView({super.key, required this.derivation});

  final Bip85Derivation derivation;

  @override
  Widget build(BuildContext context) {
    return PrivacyGuard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BullText(
              derivation.path.path,
              style: Theme.of(context).textTheme.bodyMedium,
              color: context.bull.textMuted,
            ),
            const Gap(BullSpacing.sm),
            BullMnemonicGrid(words: derivation.words),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('path', derivation.path.path));
    // words intentionally omitted.
  }
}
