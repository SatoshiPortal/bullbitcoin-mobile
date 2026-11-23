import 'package:bull_ui/app_theme.dart';
import 'package:wallet_import/src/presentation/import_l10n.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_cubit.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_failure_l10n.dart';
import 'package:wallet_import/src/presentation/watch_only/import_watch_only_state.dart';
import 'package:wallet_import/src/ui/watch_only/import_method_widget.dart';
import 'package:wallet_import/src/ui/watch_only/watch_only_details_widget.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show BullPasteInput, BullSnackBar, BullText, BullTopBar, Gap;
import 'package:go_router/go_router.dart';

class ImportWatchOnlyScreen extends StatelessWidget {
  final ImportWatchOnlyCubit Function() createCubit;
  final void Function(BuildContext) onImported;

  const ImportWatchOnlyScreen({
    super.key,
    required this.createCubit,
    required this.onImported,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => createCubit()..init(),
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: BullTopBar(
            onBack: () => context.pop(),
            title: context.loc.importWatchOnlyTitle,
          ),
        ),
        body: BlocConsumer<ImportWatchOnlyCubit, ImportWatchOnlyState>(
          listener: (context, state) {
            if (state.imported) {
              onImported(context);
            }
            if (state.failure case final failure?) {
              BullSnackBar.show(
                context,
                message: failure.toTranslated(context),
              );
            }
          },
          builder: (context, state) {
            final cubit = context.read<ImportWatchOnlyCubit>();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Center(
                  child: Column(
                    children: [
                      const Gap(32),
                      if (state.watchOnlyWallet case final wallet?)
                        WatchOnlyDetailsWidget(watchOnlyWallet: wallet)
                      else ...[
                        BullPasteInput(
                          text: state.input,
                          hint: context.loc.importWatchOnlyPasteHint,
                          onChanged: cubit.parsePastedInput,
                        ),
                        const Gap(32),
                        const ImportMethodWidget(),
                      ],
                      if (state.failure case final failure?)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: BullText(
                            failure.toTranslated(context),
                            style: TextStyle(color: context.appColors.error),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
