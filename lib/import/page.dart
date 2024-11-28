import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/nfc.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/create_sensitive.dart';
import 'package:bb_mobile/_pkg/wallet/lwk/sensitive_create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/sensitive_storage.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
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
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ImportWalletPage extends StatefulWidget {
  const ImportWalletPage({
    super.key,
    this.mainWallet = false,
    this.isRecovery = false,
  });

  final bool mainWallet;
  final bool isRecovery;

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
      walletCreate: locator<WalletCreate>(),
      walletSensCreate: locator<WalletSensitiveCreate>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      walletSensRepository: locator<WalletSensitiveStorageRepository>(),
      networkCubit: locator<NetworkCubit>(),
      bdkCreate: locator<BDKCreate>(),
      bdkSensitiveCreate: locator<BDKSensitiveCreate>(),
      lwkSensitiveCreate: locator<LWKSensitiveCreate>(),
      mainWallet: widget.mainWallet,
    );

    if (widget.isRecovery) importCubit!.recoverClicked();

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
      child: PopScope(
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: ImportAppBar(isRecovery: widget.isRecovery),
          ),
          body: const _Screen(),
        ),
      ),
    );
  }
}

class ImportAppBar extends StatelessWidget {
  const ImportAppBar({
    super.key,
    this.isRecovery = false,
  });

  final bool isRecovery;

  @override
  Widget build(BuildContext context) {
    final step =
        context.select((ImportWalletCubit cubit) => cubit.state.importStep);
    final stepName =
        context.select((ImportWalletCubit cubit) => cubit.state.stepName());
    final creatingMainWallet =
        context.select((ImportWalletCubit cubit) => cubit.state.mainWallet);
    Function()? onBack;

    if (
        // step == ImportSteps.importXpub ||
        //   step == ImportSteps.import12Words ||
        //   step == ImportSteps.import24Words ||
        //   step == ImportSteps.scanningNFC ||
        //   step == ImportSteps.scanningWallets ||

        step == ImportSteps.advancedOptions ||
            step == ImportSteps.selectWalletFormat ||
            step == ImportSteps.selectImportType)
      onBack = () => context.read<ImportWalletCubit>().backClicked();

    if (step == ImportSteps.selectCreateType) onBack = () => context.pop();

    if (creatingMainWallet &&
        (step == ImportSteps.import12Words ||
            step == ImportSteps.import24Words)) onBack = () => context.pop();

    if (isRecovery &&
        (step == ImportSteps.import12Words ||
            step == ImportSteps.import24Words)) onBack = () => context.pop();

    onBack ??= () => context.pop();

    return BBAppBar(text: stepName, onBack: onBack);
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final step =
        context.select((ImportWalletCubit cubit) => cubit.state.importStep);
    return PopScope(
      // canPop: step == ImportSteps.selectCreateType,
      onPopInvoked: (_) async {
        // context.pop();
        // if (step == ImportSteps.selectCreateType) context.pop();
        // context.read<ImportWalletCubit>().backClicked();
        // return false;
      },
      child: () {
        switch (step) {
          // return const ImportScanning(isColdCard: true);

          case ImportSteps.selectCreateType:
          // return const _CreateSelectionScreen();

          case ImportSteps.selectImportType:
          case ImportSteps.importXpub:
          // return const ImportXpubScreen();
          case ImportSteps.scanningNFC:
          case ImportSteps.import12Words:
          case ImportSteps.import24Words:
            return const ImportEnterWordsScreen();

          case ImportSteps.scanningWallets:
          case ImportSteps.selectWalletFormat:
            return const ImportSelectWalletTypeScreen();

          case ImportSteps.advancedOptions:
            return const AdvancedOptions();
          default:
            return Container();
        }
      }(),
    );
  }
}

class WalletLabel extends StatelessWidget {
  const WalletLabel();

  @override
  Widget build(BuildContext context) {
    final mainWallet =
        context.select((ImportWalletCubit cubit) => cubit.state.mainWallet);
    if (mainWallet) return const SizedBox.shrink();

    final text = context
        .select((ImportWalletCubit cubit) => cubit.state.walletLabel ?? '');
    final err = context
        .select((ImportWalletCubit cubit) => cubit.state.errSavingWallet);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBTextInput.big(
            value: text,
            onChanged: (value) =>
                context.read<ImportWalletCubit>().walletLabelChanged(value),
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
