import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/recoverbull_navigation_port.dart';
import 'package:bull_ui/bull_ui.dart';
import '../../l10n/context_localizations.dart';
import '../widgets/backup_success_screen.dart';

class TestCompletedPage extends StatelessWidget {
  const TestCompletedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BackupSuccessScreen(
      title: context.loc.recoverbullTestCompletedTitle,
      message: context.loc.recoverbullTestSuccessDescription,
      buttonLabel: context.loc.recoverbullGotIt,
      onTap: () => context.read<RecoverBullNavigationPort>().openWalletHome(),
    );
  }
}
