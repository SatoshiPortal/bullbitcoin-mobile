import 'package:bull_ui/bull_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/recoverbull_storage_mode.dart';
import '../../l10n/context_localizations.dart';

/// Explains the current session's persistence limit before a flow can proceed.
class RecoverBullStorageNotice extends StatelessWidget {
  final Widget child;

  const RecoverBullStorageNotice({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final mode =
        context.watch<RecoverBullStorageMode?>() ??
        RecoverBullStorageMode.persistent;
    if (mode == RecoverBullStorageMode.persistent) return child;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(BullSpacing.md),
            child: BullInfoBar(
              message: context.loc.recoverbullTemporaryStorageNotice,
              tone: BullInfoTone.warning,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
