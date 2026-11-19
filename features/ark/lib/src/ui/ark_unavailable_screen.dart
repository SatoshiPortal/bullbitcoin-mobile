import 'package:bull_ui/bull_ui.dart';

import '../presentation/ark_l10n.dart';

/// Honest entry while the host has no configured native module.
class ArkUnavailableScreen extends StatelessWidget {
  const ArkUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = arkLocalizationsOf(context);
    return BullScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(BullSpacing.md),
          child: Column(
            children: [
              BullTopBar(
                title: l10n.title,
                onBack: Navigator.canPop(context)
                    ? () => Navigator.pop(context)
                    : null,
              ),
              BullInfoBar(message: l10n.nativeUnavailable),
            ],
          ),
        ),
      ),
    );
  }
}
