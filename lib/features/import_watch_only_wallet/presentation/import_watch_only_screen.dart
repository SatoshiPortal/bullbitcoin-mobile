import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/paste_input.dart';
import 'package:bb_mobile/core/widgets/navbar/top_bar.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_descriptor_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_xpub_usecase.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_cubit.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/cubit/import_watch_only_state.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/import_method_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/presentation/watch_only_details_widget.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ImportWatchOnlyScreen extends StatelessWidget {
  final WatchOnlyWalletEntity? watchOnlyWallet;

  const ImportWatchOnlyScreen({super.key, this.watchOnlyWallet});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => ImportWatchOnlyCubit(
            watchOnlyWallet: watchOnlyWallet,
            importWatchOnlyDescriptorUsecase:
                locator<ImportWatchOnlyDescriptorUsecase>(),
            importWatchOnlyXpubUsecase: locator<ImportWatchOnlyXpubUsecase>(),
          )..init(),
      child: Scaffold(
        backgroundColor: context.colour.secondaryFixed,
        appBar: AppBar(
          forceMaterialTransparency: true,
          automaticallyImplyLeading: false,
          flexibleSpace: TopBar(
            title: 'Import wallet',
            color: context.colour.secondaryFixed,
            onBack: () => Navigator.of(context).pop(),
          ),
        ),
        body: BlocConsumer<ImportWatchOnlyCubit, ImportWatchOnlyState>(
          listener: (context, state) {
            if (state.importedWallet != null) {
              context.goNamed(WalletRoute.walletHome.name);
            }
            if (state.error.isNotEmpty) {
              SnackBarUtils.showSnackBar(context, state.error);
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
                      if (state.watchOnlyWallet == null) ...[
                        PasteInput(
                          text: state.input,
                          hint: 'Paste xpub, ypub, zpub or descriptor',
                          onChanged: cubit.parsePastedInput,
                        ),
                        if (state.error.isNotEmpty)
                          Center(
                            child: BBText(
                              state.error,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const Gap(32),
                        const ImportMethodWidget(),
                      ] else
                        WatchOnlyDetailsWidget(
                          watchOnlyWallet: state.watchOnlyWallet!,
                          cubit: cubit,
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
