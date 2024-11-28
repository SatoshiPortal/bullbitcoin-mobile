import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository/storage.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/controls.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/import/hardware_import_bloc/hardware_import_cubit.dart';
import 'package:bb_mobile/import/listeners.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class HardwareImportPage extends StatefulWidget {
  const HardwareImportPage({super.key});

  @override
  State<HardwareImportPage> createState() => _HardwareImportPageState();
}

class _HardwareImportPageState extends State<HardwareImportPage> {
  late HardwareImportCubit _hardwareImportCubit;

  @override
  void initState() {
    _hardwareImportCubit = HardwareImportCubit(
      barcode: locator<Barcode>(),
      walletsStorageRepository: locator<WalletsStorageRepository>(),
      networkCubit: locator<NetworkCubit>(),
      bdkCreate: locator<BDKCreate>(),
      filePicker: locator<FilePick>(),
    );
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _hardwareImportCubit),
        BlocProvider.value(value: ScrollCubit()),
      ],
      child: HardwareImportListeners(
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            flexibleSpace: BBAppBar(
              text: 'Import wallet',
              onBack: () {
                context.pop();
              },
            ),
          ),
          body: Builder(
            builder: (context) {
              return SingleChildScrollView(
                controller: context.read<ScrollCubit>().state,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: _Screen(),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    final isInputScreen = context.select(
      (HardwareImportCubit _) => _.state.inputScreen(),
    );

    final isColdcard = context.select(
      (HardwareImportCubit _) => _.state.tempColdCard != null,
    );

    if (isInputScreen) {
      return const InputScreen();
    } else if (isColdcard) {
      return const ColdCardDetails();
    } else {
      return const XpubDetails();
    }
  }
}

class InputScreen extends StatelessWidget {
  const InputScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = context.select(
      (HardwareImportCubit _) => _.state.scanningInput,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IgnorePointer(
          ignoring: loading,
          child: AnimatedOpacity(
            opacity: loading ? 0.3 : 1,
            duration: 300.ms,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Gap(24),
                BBText.body(
                  'Import a hardware wallet device or any external Bitcoin wallet',
                  isBold: true,
                ),
                Gap(24),
                BBText.bodySmall('Paste or scan xpub or zpub'),
                Gap(4),
                XpubField(),
                Gap(24),
                UploadButton(),
                Gap(8),
                ScanButton(),
              ],
            ),
          ),
        ),
        const Gap(24),
        if (loading) const BBLoadingRow(),
      ],
    );
  }
}

class XpubDetails extends StatelessWidget {
  const XpubDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final xpub = context.select(
      (HardwareImportCubit _) => _.state.inputText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(24),
        const BBText.body(
          'Wallet detected',
          isBold: true,
        ),
        const Gap(8),
        BBText.bodySmall(xpub),
        const Gap(24),
        const ScriptSelectionDropdown(),
        const LabelField(),
        const Gap(40),
        const ImportButton(),
      ],
    );
  }
}

class ColdCardDetails extends StatelessWidget {
  const ColdCardDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final cc = context.select(
      (HardwareImportCubit _) => _.state.tempColdCard!,
    );
    final scriptType = context.select(
      (HardwareImportCubit _) => _.state.selectScriptType,
    );

    final identity = cc.xfp!;
    final pubkey = cc.bip84!.xpub;

    final firstAddress = scriptType == ScriptType.bip84
        ? cc.bip84!.first!
        : scriptType == ScriptType.bip49
            ? cc.bip49!.first!
            : cc.bip44!.first!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Gap(24),
        const BBText.body(
          'Coldcard wallet detected',
          isBold: true,
        ),
        const Gap(16),
        const BBText.body('Identity'),
        const Gap(4),
        BBText.body(identity),
        const Gap(24),
        const ScriptSelectionDropdown(),
        // const Gap(8),
        const BBText.body('Master public key'),
        const Gap(4),
        BBText.body(pubkey!),
        const Gap(24),
        const BBText.body('First wallet address'),
        const Gap(4),
        BBText.body(firstAddress),
        const Gap(24),
        const LabelField(),
        const Gap(40),
        const ImportButton(),
      ],
    );
  }
}

class XpubField extends StatelessWidget {
  const XpubField({super.key});

  @override
  Widget build(BuildContext context) {
    final xpub =
        context.select((HardwareImportCubit cubit) => cubit.state.inputText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Gap(8),
            Expanded(
              child: BBTextInput.multiLine(
                value: xpub,
                onChanged: (value) {
                  context.read<HardwareImportCubit>().updateInputText(value);
                },
                rightIcon: IconButton(
                  onPressed: () async {
                    if (!locator.isRegistered<Clippboard>()) return;
                    final data = await locator<Clippboard>().paste();
                    if (data == null) return;
                    context.read<HardwareImportCubit>().updateInputText(data);
                  },
                  iconSize: 20,
                  color: context.colour.surface,
                  icon: const FaIcon(FontAwesomeIcons.paste),
                ),
                // rightIcon: Column(
                //   crossAxisAlignment: CrossAxisAlignment.end,
                //   children: [
                //     // IconButton(
                //     //   icon: FaIcon(
                //     //     FontAwesomeIcons.qrcode,
                //     //     color: context.colour.surface,
                //     //   ),
                //     //   onPressed: () {
                //     //     context.read<ImportWalletCubit>().scanQRClicked();
                //     //   },
                //     // ),
                //     // const Gap(4),
                //     IconButton(
                //       onPressed: () async {
                //         if (!locator.isRegistered<Clippboard>()) return;
                //         final data = await locator<Clippboard>().paste();
                //         if (data == null) return;
                //         context.read<ImportWalletCubit>().xpubChanged(data);
                //       },
                //       iconSize: 20,
                //       color: context.colour.surface,
                //       icon: const FaIcon(FontAwesomeIcons.paste),
                //     ),
                //   ],
                // ),
                hint: 'Paste or scan xpub',
              ),
            ),
            const Gap(8),
          ],
        ),
      ],
    );
  }
}

class LabelField extends StatelessWidget {
  const LabelField({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.select(
      (HardwareImportCubit cubit) => cubit.state.label,
    );
    final err =
        context.select((HardwareImportCubit cubit) => cubit.state.errLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.body('Add a label'),
        const Gap(4),
        BBTextInput.big(
          value: text,
          onChanged: (value) =>
              context.read<HardwareImportCubit>().updateLabel(value),
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
    );
  }
}

class UploadButton extends StatelessWidget {
  const UploadButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Upload File',
      center: true,
      onPressed: () {
        context.read<HardwareImportCubit>().selectFile();
      },
    );
  }
}

class ScanButton extends StatelessWidget {
  const ScanButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BBButton.big(
      label: 'Scan QR code',
      center: true,
      onPressed: () {
        context.read<HardwareImportCubit>().scanQRClicked();
      },
    );
  }
}

class ImportButton extends StatelessWidget {
  const ImportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final saving = context.select(
      (HardwareImportCubit cubit) => cubit.state.savingWallet,
    );

    final err = context.select(
      (HardwareImportCubit cubit) => cubit.state.errSavingWallet,
    );
    return Column(
      children: [
        BBButton.big(
          label: 'Import wallet',
          loadingText: 'Importing...',
          center: true,
          loading: saving,
          disabled: saving,
          onPressed: () {
            context.read<HardwareImportCubit>().saveClicked();
          },
        ),
        if (err.isNotEmpty) ...[
          const Gap(8),
          Center(child: BBText.error(err)),
        ],
      ],
    );
  }
}

class ScriptSelectionDropdown extends StatelessWidget {
  const ScriptSelectionDropdown({super.key});

  @override
  Widget build(BuildContext context) {
    final wallets = context.select(
      (HardwareImportCubit cubit) => cubit.state.walletDetails,
    );
    if (wallets?.length == 1) return const SizedBox.shrink();

    final selectedWalletType = context.select(
      (HardwareImportCubit cubit) => cubit.state.selectScriptType,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.body('Select wallet type'),
        const Gap(4),
        BBDropDown<ScriptType>(
          isCentered: false,
          onChanged: (v) {
            context.read<HardwareImportCubit>().updateSelectScriptType(v);
          },
          value: selectedWalletType,
          items: {
            for (final wallet in wallets!)
              wallet.scriptType: (
                label: wallet.scriptType.getScriptString(),
                enabled: true,
                imagePath: null
              ),
          },
        ),
        const Gap(24),
      ],
    );
  }
}
