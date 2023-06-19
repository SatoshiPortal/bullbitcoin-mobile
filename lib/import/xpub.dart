import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/indicators.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/import/bloc/import_cubit.dart';
import 'package:bb_mobile/import/bloc/import_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

class ImportXpubScreen extends StatelessWidget {
  const ImportXpubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Gap(32),
          Padding(
            padding: EdgeInsets.all(24.0),
            child: BBText.bodySmall(desc),
          ),
          Gap(16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.only(left: 18.0),
                  child: BBText.title(
                    'Master public key (xpub, zpub)',
                  ),
                ),
                Gap(8),
                XpubTextFieldArea(),
              ],
            ),
          ),
          Gap(40),
          ColdCardSection(),
          _ImportButtons(),
          Gap(80),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn();
  }
}

class ColdCardSection extends StatelessWidget {
  const ColdCardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final loading =
        context.select((ImportWalletCubit cubit) => cubit.state.loadingFile);
    final scanning = context.select((ImportWalletCubit cubit) =>
        cubit.state.importStep == ImportSteps.scanningNFC);

    final err =
        context.select((ImportWalletCubit cubit) => cubit.state.errLoadingFile);

    if (loading)
      return const Center(child: CircularProgressIndicator())
          .animate(delay: 300.ms)
          .fadeIn();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBText.headline(
            'ColdCard',
            isRed: true,
            isBold: true,
          ),
          const Gap(16),
          BBButton.textWithRightArrow(
            onPressed: () {
              context.read<ImportWalletCubit>().coldCardFileClicked();
            },
            label: 'Upload file',
          ),
          BBButton.textWithRightArrow(
            onPressed: () {
              if (!scanning)
                context.read<ImportWalletCubit>().coldCardNFCClicked();
              else
                context.read<ImportWalletCubit>().backClicked();
            },
            label: 'Activate NFC',
            loading: scanning,
            loadingText: 'Stop Scanning',
          ),
          const Gap(24),
          if (err.isNotEmpty)
            BBText.error(
              err,
            ),
        ],
      ),
    );
  }
}

class XpubTextFieldArea extends StatefulWidget {
  const XpubTextFieldArea({
    super.key,
  });

  @override
  State<XpubTextFieldArea> createState() => _XpubTextFieldAreaState();
}

class _XpubTextFieldAreaState extends State<XpubTextFieldArea> {
  @override
  Widget build(BuildContext context) {
    final xpub = context.select((ImportWalletCubit cubit) => cubit.state.xpub);

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
                  context.read<ImportWalletCubit>().xpubChanged(value);
                },
                rightIcon: IconButton(
                  icon: FaIcon(
                    FontAwesomeIcons.qrcode,
                    color: context.colour.surface,
                  ),
                  onPressed: () {
                    context.read<ImportWalletCubit>().scanQRClicked();
                  },
                ),
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

class _ImportButtons extends StatelessWidget {
  const _ImportButtons();

  @override
  Widget build(BuildContext context) {
    final err =
        context.select((ImportWalletCubit cubit) => cubit.state.errImporting);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BBButton.text(label: 'Hardware wallet instruction', onPressed: () {}),
          BBButton.text(
            label: 'Advanced Options',
            onPressed: () {
              AdvancedOptions.openPopUp(context);
            },
          ),
          const Gap(16),
          BBButton.bigRed(
            label: 'Import',
            onPressed: () {
              context.read<ImportWalletCubit>().xpubSaveClicked();
            },
          ),
          const Gap(8),
          if (err.isNotEmpty) BBText.error(err, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions();

  static Future openPopUp(BuildContext context) async {
    final import = context.read<ImportWalletCubit>();
    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: import,
        child: const PopUpBorder(
          child: AdvancedOptions(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final xpub = context.select((ImportWalletCubit cubit) => cubit.state.xpub);
    final path =
        context.select((ImportWalletCubit x) => x.state.customDerivation);
    final fingerprint =
        context.select((ImportWalletCubit x) => x.state.fingerprint);
    final combined = context.select(
        (ImportWalletCubit x) => x.state.manualCombinedDescriptor ?? '');
    final descr =
        context.select((ImportWalletCubit x) => x.state.manualDescriptor ?? '');
    final cdescr = context.select(
        (ImportWalletCubit x) => x.state.manualCombinedDescriptor ?? '');

    final err =
        context.select((ImportWalletCubit cubit) => cubit.state.errImporting);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBHeader.popUpCenteredText(
              text: 'Advanced Options', isLeft: true),
          BBTextInput.multiLine(
            value: xpub,
            onChanged: (value) {
              context.read<ImportWalletCubit>().xpubChanged(value);
            },
            rightIcon: IconButton(
              icon: FaIcon(
                FontAwesomeIcons.qrcode,
                color: context.colour.onBackground,
              ),
              onPressed: () {
                context.read<ImportWalletCubit>().scanQRClicked();
              },
            ),
            hint: 'Paste or scan xpub',
          ),
          const Gap(16),
          BBTextInput.big(
            onChanged: (txt) {
              context.read<ImportWalletCubit>().customDerivationChanged(txt);
            },
            value: path,
            hint: 'Custom derivation path',
          ),
          const Gap(16),
          BBTextInput.big(
            onChanged: (txt) {
              context.read<ImportWalletCubit>().fingerprintChanged(txt);
            },
            value: fingerprint,
            hint: 'Fingerprint',
          ),
          const Gap(16),
          Center(
            child: Container(
              width: 100,
              height: 2,
              color: context.colour.surface,
            ),
          ),
          const Gap(16),
          BBTextInput.big(
            onChanged: (txt) {
              context.read<ImportWalletCubit>().combinedDescriptorChanged(txt);
            },
            value: combined,
            hint: 'Combined Descriptor',
          ),
          const Gap(16),
          BBTextInput.big(
            onChanged: (txt) {
              context.read<ImportWalletCubit>().descriptorChanged(txt);
            },
            value: descr,
            hint: 'Descriptor',
          ),
          const Gap(16),
          BBTextInput.big(
            onChanged: (txt) {
              context.read<ImportWalletCubit>().cDescriptorChanged(txt);
            },
            value: cdescr,
            hint: 'Change Descriptor',
          ),
          const Gap(40),
          BBButton.bigRed(
            label: 'Import',
            onPressed: () {
              context.read<ImportWalletCubit>().xpubSaveClicked();
            },
          ),
          const Gap(16),
          if (err.isNotEmpty) BBText.error(err, textAlign: TextAlign.center),
          const Gap(80),
        ],
      ),
    );
  }
}

class ImportScanning extends StatelessWidget {
  const ImportScanning({super.key, required this.isColdCard});

  final bool isColdCard;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isColdCard) ...[
          const BBText.title(
            'ColdCard',
            isRed: true,
            isBold: true,
          ),
          const Gap(16),
        ],
        const BBText.title(
          'Scanning for wallets',
          isRed: true,
        ),
        const Gap(16),
        const BBLoadingRow(),
      ],
    );
  }
}

const steps = '''
1. Unlock device
2. Select menu on top-left corner
3. Select “Multisig Wallet"
4. Select ellipsis on top-right corner
5. Select “Import from QR Code"
6. Use Bull Bitcoin to scan QR code
''';

const desc =
    'Import a hardware wallet or an external Bitcoin wallet. You will be able to monitor your balance and transactions, receive Bitcoin and create unsigned Bitcoin transactions (PSBT).';
