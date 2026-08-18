import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/parse_watch_only_input_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_watch_only_failure_l10n.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_method_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/watch_only_details_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ImportWatchOnlyScreen extends StatelessWidget {
  final WatchOnlyWalletEntity? watchOnlyWallet;

  const ImportWatchOnlyScreen({super.key, this.watchOnlyWallet});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ImportWatchOnlyCubit(
        watchOnlyWallet: watchOnlyWallet,
        importWatchOnlyDescriptorUsecase:
            locator<ImportWatchOnlyDescriptorUsecase>(),
        importWatchOnlyXpubUsecase: locator<ImportWatchOnlyXpubUsecase>(),
        parseWatchOnlyInputUsecase: locator<ParseWatchOnlyInputUsecase>(),
        settingsRepository: locator(),
      )..init(),
      child: BullPage(
        topBar: BullTopBar(
          onBack: () => context.pop(),
          title: context.loc.importWatchOnlyTitle,
        ),
        child: BlocConsumer<ImportWatchOnlyCubit, ImportWatchOnlyState>(
          listener: (context, state) {
            if (state.importedWallet != null) {
              // Trigger wallet refresh before navigating to home
              context.read<WalletBloc>().add(const WalletStarted());
              context.goNamed(WalletRoute.walletHome.name);
            }
            if (state.failure != null) {
              SnackBarUtils.showSnackBar(
                context,
                state.failure!.toTranslated(context),
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
                      if (state.watchOnlyWallet != null)
                        WatchOnlyDetailsWidget(
                          watchOnlyWallet: state.watchOnlyWallet!,
                        )
                      else ...[
                        BullPasteInput(
                          text: state.input,
                          hint: context.loc.importWatchOnlyPasteHint,
                          onChanged: cubit.parsePastedInput,
                        ),
                        if (state.failure != null)
                          Center(
                            child: BullText(
                              state.failure!.toTranslated(context),
                              style: Theme.of(context).textTheme.bodyMedium,
                              color: context.appColors.error,
                            ),
                          ),
                        const Gap(32),
                        const ImportMethodWidget(),
                      ],
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
