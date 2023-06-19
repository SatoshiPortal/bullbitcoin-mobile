import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/import/recover.dart';
import 'package:bb_mobile/import/wallet_type_selection.dart';
import 'package:bb_mobile/import/xpub.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ImportWalletPage extends StatefulWidget {
  const ImportWalletPage({super.key});

  @override
  State<ImportWalletPage> createState() => _ImportWalletPageState();
}

class _ImportWalletPageState extends State<ImportWalletPage> {
  ImportWalletCubit? importCubit;

  @override
  void initState() {
    importCubit = ImportWalletCubit(
      barcode: locator<Barcode>(),
      filePicker: locator<FilePick>(),
      nfc: locator<NFCPicker>(),
      settingsCubit: locator<SettingsCubit>(),
      walletCreate: locator<WalletCreate>(),
      storage: locator<IStorage>(),
      walletUpdate: locator<WalletUpdate>(),
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: importCubit!,
      child: const _Page(),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: const ImportAppBar(),
      ),
      body: const _Screen(),
    );
  }
}

class ImportAppBar extends StatelessWidget {
  const ImportAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final step =
        context.select((ImportWalletCubit cubit) => cubit.state.importStep);
    final stepName =
        context.select((ImportWalletCubit cubit) => cubit.state.stepName());
    Function()? onBack;

    if (step == ImportSteps.importXpub ||
        step == ImportSteps.importWords ||
        step == ImportSteps.importWords ||
        step == ImportSteps.scanningNFC ||
        step == ImportSteps.scanningWallets ||
        step == ImportSteps.advancedOptions ||
        step == ImportSteps.selectWalletType ||
        step == ImportSteps.selectImportType)
      onBack = () => context.read<ImportWalletCubit>().backClicked();

    if (step == ImportSteps.selectCreateType) onBack = () => context.pop();

    return BBAppBar(text: stepName, onBack: onBack);
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final step =
        context.select((ImportWalletCubit cubit) => cubit.state.importStep);
    return WillPopScope(
      onWillPop: () async {
        if (step == ImportSteps.selectCreateType) return true;
        context.read<ImportWalletCubit>().backClicked();
        return false;
      },
      child: () {
        switch (step) {
          case ImportSteps.selectCreateType:
            return const _CreateSelectionScreen();

          case ImportSteps.selectImportType:
          case ImportSteps.importXpub:
            return const ImportXpubScreen();
          case ImportSteps.scanningNFC:
            return const ImportScanning(isColdCard: true);

          case ImportSteps.advancedOptions:
            return const AdvancedOptions();
          case ImportSteps.importWords:
            return const ImportEnterWordsScreen();

          case ImportSteps.scanningWallets:
          case ImportSteps.selectWalletType:
            return const ImportSelectWalletTypeScreen();
          default:
            return Container();
        }
      }(),
    );
  }
}

class _CreateSelectionScreen extends StatelessWidget {
  const _CreateSelectionScreen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBButton.bigRed(
            onPressed: () {
              context.push('/create-wallet');
            },
            label: 'Create new wallet',
          ),
          const Gap(16),
          BBButton.bigRed(
            onPressed: () {
              context.read<ImportWalletCubit>().importClicked();
            },
            label: 'Import wallet',
          ),
          const Gap(16),
          BBButton.bigRed(
            onPressed: () {
              context.read<ImportWalletCubit>().recoverClicked();
            },
            label: 'Recover backup',
          ),
        ],
      ),
    );
  }
}
