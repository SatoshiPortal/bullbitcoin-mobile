import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bb_mobile/generated/flutter_gen/assets.gen.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:gif/gif.dart';
import 'package:material_ui/material_ui.dart' show AssetImage, MediaQuery;

class BackupTestSuccessScreen extends StatelessWidget {
  const BackupTestSuccessScreen({super.key, required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final loc = context.loc;
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: .spaceBetween,
          children: <Widget>[
            const Spacer(),
            Column(
              children: [
                SizedBox(
                  height: 200,
                  width: 200,
                  child: Gif(
                    image: AssetImage(Assets.animations.successTick.path),
                    autostart: Autostart.once,
                    height: 200,
                    width: 200,
                  ),
                ),
                const Gap(8),
                Semantics(
                  header: true,
                  child: BullText(
                    loc.testBackupSuccessTitle,
                    role: BullTextRole.subtitle,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Gap(8),
                BullText(
                  loc.testBackupSuccessMessage,
                  role: BullTextRole.body,
                  textAlign: .center,
                ),
              ],
            ),
            const Spacer(flex: 2),
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).size.height * 0.05,
              ),
              child: BullButton.secondary(
                label: loc.testBackupSuccessButton,
                onPressed: onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
