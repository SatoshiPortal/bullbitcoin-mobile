import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/consts/keys.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/import/bloc/words_cubit.dart';
import 'package:bb_mobile/import/recover.dart';
import 'package:bb_mobile/import/wallet_type_selection.dart';
import 'package:bb_mobile/import/xpub.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  WordsCubit? wordsCubit;

  @override
  void initState() {
    importCubit = ImportWalletCubit(
      barcode: locator<Barcode>(),
      filePicker: locator<FilePick>(),
      nfc: locator<NFCPicker>(),
      settingsCubit: locator<SettingsCubit>(),
      walletCreate: locator<WalletCreate>(),
      walletSensCreate: locator<WalletSensitiveCreate>(),
      hiveStorage: locator<HiveStorage>(),
      secureStorage: locator<SecureStorage>(),
      walletRepository: locator<WalletRepository>(),
      walletSensRepository: locator<WalletSensitiveRepository>(),
      networkCubit: locator<NetworkCubit>(),
    );

    wordsCubit = locator<WordsCubit>();

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: importCubit!),
        BlocProvider.value(value: wordsCubit!),
      ],
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
    final step = context.select((ImportWalletCubit cubit) => cubit.state.importStep);
    final stepName = context.select((ImportWalletCubit cubit) => cubit.state.stepName());
    final creatingMainWallet = context.select((ImportWalletCubit cubit) => cubit.state.mainWallet);
    Function()? onBack;

    if (step == ImportSteps.importXpub ||
        step == ImportSteps.import12Words ||
        step == ImportSteps.import24Words ||
        step == ImportSteps.scanningNFC ||
        step == ImportSteps.scanningWallets ||
        step == ImportSteps.advancedOptions ||
        step == ImportSteps.selectWalletFormat ||
        step == ImportSteps.selectImportType)
      onBack = () => context.read<ImportWalletCubit>().backClicked();

    if (step == ImportSteps.selectCreateType) onBack = () => context.pop();

    if (creatingMainWallet &&
        (step == ImportSteps.import12Words || step == ImportSteps.import24Words))
      onBack = () => context.pop();

    return BBAppBar(text: stepName, onBack: onBack);
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final step = context.select((ImportWalletCubit cubit) => cubit.state.importStep);
    return PopScope(
      canPop: step == ImportSteps.selectCreateType,
      onPopInvoked: (_) async {
        // if (step == ImportSteps.selectCreateType) context.pop();
        context.read<ImportWalletCubit>().backClicked();
        // return false;
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
          case ImportSteps.import12Words:
          case ImportSteps.import24Words:
            return const ImportEnterWordsScreen();

          case ImportSteps.scanningWallets:
          case ImportSteps.selectWalletFormat:
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
          BBButton.big(
            onPressed: () {
              context.push('/create-wallet');
            },
            label: 'Create new wallet',
          ),
          const Gap(16),
          BBButton.big(
            onPressed: () {
              context.read<ImportWalletCubit>().importClicked();
            },
            label: 'Import wallet',
          ),
          const Gap(16),
          BBButton.big(
            buttonKey: UIKeys.importRecoverButton,
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

class WalletLabel extends StatelessWidget {
  const WalletLabel();

  @override
  Widget build(BuildContext context) {
    final text = context.select((ImportWalletCubit cubit) => cubit.state.walletLabel ?? '');
    final err = context.select((ImportWalletCubit cubit) => cubit.state.errSavingWallet);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBTextInput.big(
            value: text,
            onChanged: (value) => context.read<ImportWalletCubit>().walletLabelChanged(value),
            onEnter: () async {
              await Future.delayed(500.ms);
              context.read<ScrollCubit>().state.animateTo(
                    context.read<ScrollCubit>().state.position.maxScrollExtent,
                    duration: 300.milliseconds,
                    curve: Curves.linear,
                  );
            },
            hint: 'Label your wallet',
          ),
          if (err.isNotEmpty) ...[
            const Gap(8),
            Center(child: BBText.error(err)),
          ],
        ],
      ),
    );
  }
}
