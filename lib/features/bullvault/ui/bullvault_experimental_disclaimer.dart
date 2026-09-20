import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

Future<void> openBullVaultMenu(BuildContext context) async {
  final accepted = await BullDialog.show<bool>(
    context: context,
    builder: (dialogContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.loc.bullVaultExperimentalWarningTitle,
          style: context.bullText.titleMedium,
        ),
        const Gap(8),
        Text(context.loc.bullVaultExperimentalWarningMessage),
        const Gap(20),
        BullButton.small(
          label: context.loc.cancelButton,
          onPressed: () => Navigator.of(dialogContext).pop(false),
          bgColor: context.bull.surface,
          textColor: context.bull.text,
          outlined: true,
        ),
        const Gap(8),
        BullButton.small(
          label: context.loc.continueButton,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          bgColor: context.bull.primary,
          textColor: context.bull.onPrimary,
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    await context.pushNamed<void>(BullVaultFacade.menuRouteName);
  }
}
