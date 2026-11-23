import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullBackupOptionCard,
        BullBottomSheet,
        BullText,
        BullThemeX,
        BullTopBar,
        Gap,
        BullTypographyX;
import 'package:go_router/go_router.dart';

import '../backups_copy.dart';
import 'how_to_decide.dart';

class BackupOptionsScreen extends StatelessWidget {
  final BackupsCopy copy;
  final bool verify;
  final Widget encryptedIcon;
  final Widget physicalIcon;
  final void Function(BuildContext) onOpenPhysical;

  const BackupOptionsScreen({
    super.key,
    required this.copy,
    required this.verify,
    required this.encryptedIcon,
    required this.physicalIcon,
    required this.onOpenPhysical,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        forceMaterialTransparency: true,
        automaticallyImplyLeading: false,
        flexibleSpace: BullTopBar(
          onBack: () => context.pop(),
          title: verify ? copy.testTitle : copy.backupTitle,
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const Gap(20),
            BullText(
              copy.importanceWarning,
              textAlign: .center,
              style: context.bullType.body.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 5,
            ),
            const Gap(16),
            MergeSemantics(
              child: Semantics(
                button: true,
                child: BullBackupOptionCard(
                  icon: encryptedIcon,
                  title: copy.encrypted.title,
                  description: copy.encrypted.description,
                  tag: copy.encrypted.tag,
                  onTap: () => RecoverBullFeature.open(
                    context,
                    verify
                        ? RecoverBullFlow.testVault
                        : RecoverBullFlow.secureVault,
                  ),
                ),
              ),
            ),
            const Gap(16),

            MergeSemantics(
              child: Semantics(
                button: true,
                child: BullBackupOptionCard(
                  icon: physicalIcon,
                  title: copy.physical.title,
                  description: copy.physical.description,
                  tag: copy.physical.tag,
                  onTap: () => onOpenPhysical(context),
                ),
              ),
            ),
            const Gap(16),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: () {
                  BullBottomSheet.show(
                    context: context,
                    child: HowToDecideBackupOption(copy: copy),
                  );
                },
                child: BullText(
                  copy.helpLabel,
                  style: context.bullType.subtitle
                      .copyWith(fontWeight: FontWeight.w700)
                      .copyWith(color: context.bull.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
