import 'package:bb_mobile/localization/app_localizations_context.dart';
import 'package:bull_ui/bull_ui.dart';

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BullScaffold(
      backgroundColor: context.bull.background,
      body: Center(
        child: Semantics(
          header: true,
          child: BullText(
            context.loc.coreScreensPageNotFound,
            role: BullTextRole.body,
          ),
        ),
      ),
    );
  }
}
