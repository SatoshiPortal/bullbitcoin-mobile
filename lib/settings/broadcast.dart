import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/update.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_cubit.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BroadcasePopUp extends StatelessWidget {
  const BroadcasePopUp({super.key});

  static Future openPopUp(BuildContext context) {
    final broadcast = BroadcastTxCubit(
      barcode: locator<Barcode>(),
      filePicker: locator<FilePick>(),
      settingsCubit: locator<SettingsCubit>(),
      fileStorage: locator<FileStorage>(),
      walletUpdate: locator<WalletUpdate>(),
    );

    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: broadcast,
        child: BlocListener<BroadcastTxCubit, BroadcastTxState>(
          listenWhen: (previous, current) => previous.sent != current.sent,
          listener: (context, state) async {
            if (state.sent) {
              await Future.delayed(3.seconds);
              context.pop();
            }
          },
          child: const BroadcasePopUp(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopUpBorder(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 14),
                const BBText.body(
                  'Import Transaction',
                ),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: const FaIcon(
                    FontAwesomeIcons.xmark,
                    size: 14,
                  ),
                ),
              ],
            ),
            const Gap(24),
            Center(
              child: GestureDetector(
                onTap: () {
                  context.read<BroadcastTxCubit>().scanQRClicked();
                },
                child: SizedBox(
                  height: MediaQuery.of(context).size.width * 0.7,
                  width: MediaQuery.of(context).size.width * 0.7,
                  child: Material(
                    borderRadius: BorderRadius.circular(24),
                    color: context.colour.surface.withOpacity(0.3),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(
                            FontAwesomeIcons.camera,
                            size: 64,
                            color: context.colour.onPrimary,
                          ),
                          const Gap(8),
                          const BBText.body(
                            'Scan Txn',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Gap(24),
            Center(
              child: SizedBox(
                width: 300,
                child: BBButton.bigBlack(
                  filled: true,
                  onPressed: () {
                    context.read<BroadcastTxCubit>().uploadFileClicked();
                  },
                  label: 'UPLOAD FILE',
                ),
              ),
            ),
            const Gap(24),
            const BBText.body(
              '    Transaction',
            ),
            const Gap(4),
            const _TxTextField(),
            const Gap(80),
            const SendButton(),
            const Gap(48),
          ],
        ),
      ),
    );
  }
}

class _TxTextField extends StatefulWidget {
  const _TxTextField();

  @override
  State<_TxTextField> createState() => _TxTextFieldState();
}

class _TxTextFieldState extends State<_TxTextField> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final tx = context.select((BroadcastTxCubit cubit) => cubit.state.tx);
    if (tx != _controller.text) _controller.text = tx;

    return BBTextInput.big(
      value: tx,
      hint: 'Enter Transaction',
      onChanged: (value) {
        context.read<BroadcastTxCubit>().txChanged(value);
      },
    );
  }
}

class BroadcastSend extends StatelessWidget {
  const BroadcastSend({super.key});

  @override
  Widget build(BuildContext context) {
    final tx = context.select((BroadcastTxCubit cubit) => cubit.state.transaction);
    final psbt = context.select((BroadcastTxCubit cubit) => cubit.state.psbtBDK);
    if (tx == null || psbt == null) return const SizedBox();

    final txamt = context.select(
      (BroadcastTxCubit cubit) => cubit.state.transaction?.getAmount() ?? 0,
    );
    final txfee = context.select((BroadcastTxCubit cubit) => cubit.state.transaction?.fee ?? 0);

    final amt = context.select((SettingsCubit cubit) => cubit.state.getAmountInUnits(txamt));
    final fee = context.select((SettingsCubit cubit) => cubit.state.getAmountInUnits(txfee));
    final psbtStr = psbt.psbtBase64;

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(width: 14),
              const BBText.body(
                'Broadcast tx',
              ),
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const FaIcon(
                  FontAwesomeIcons.xmark,
                  size: 14,
                ),
              ),
            ],
          ),
          const Gap(24),
          const BBText.body(
            'Amount Send',
          ),
          const Gap(4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Container(
                transformAlignment: Alignment.center,
                transform: Matrix4.identity()..rotateZ(-1),
                child: const FaIcon(
                  FontAwesomeIcons.arrowRight,
                  size: 12,
                ),
              ),
              const Gap(8),
              BBText.body(
                amt,
              ),
            ],
          ),
          const Gap(24),
          const BBText.body(
            'Network Fee',
          ),
          const Gap(4),
          BBText.body(
            fee,
          ),
          const Gap(24),
          const DownloadButton(),
          const Gap(16),
          const Center(
            child: BBText.body(
              'Scan Txn',
            ),
          ),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(data: psbtStr),
            ),
          ),
          const Gap(60),
          const SendButton(),
          const Gap(48),
        ],
      ),
    );
  }
}

class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key});

  @override
  Widget build(BuildContext context) {
    final downloading = context.select((BroadcastTxCubit cubit) => cubit.state.downloadingFile);
    final downloaded = context.select((BroadcastTxCubit cubit) => cubit.state.downloaded);

    if (downloaded)
      return Center(
        child: const BBText.body(
          'Downloaded',
        ).animate(delay: 300.ms).fadeIn(),
      );

    return Center(
      child: SizedBox(
        width: 300,
        child: BBButton.bigBlack(
          filled: true,
          loading: downloading,
          onPressed: () {
            context.read<BroadcastTxCubit>().uploadFileClicked();
          },
          label: 'UPLOAD FILE',
        ),
      ),
    );
  }
}

class SendButton extends StatelessWidget {
  const SendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final step = context.select((BroadcastTxCubit cubit) => cubit.state.step);
    final hasErr = context.select((BroadcastTxCubit cubit) => cubit.state.hasErr());
    final err = context.select((BroadcastTxCubit cubit) => cubit.state.getErrors());

    final broadcasting = context.select((BroadcastTxCubit cubit) => cubit.state.broadcastingTx);
    final extractingTx = context.select((BroadcastTxCubit cubit) => cubit.state.extractingTx);
    final loading = broadcasting || extractingTx;

    final sent = context.select((BroadcastTxCubit cubit) => cubit.state.sent);

    if (sent)
      return const Center(
        child: BBText.body(
          'Tx Broadcasted!',
        ),
      ).animate(delay: 300.ms).fadeIn();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasErr) ...[
          BBText.body(
            err,
          ),
          const Gap(16),
        ],
        Center(
          child: SizedBox(
            width: 300,
            child: BBButton.bigRed(
              loading: loading,
              onPressed: () {
                // if (loading) return;
                if (step == BroadcastTxStep.import)
                  context.read<BroadcastTxCubit>().extractTxClicked();
                if (step == BroadcastTxStep.broadcast)
                  context.read<BroadcastTxCubit>().broadcastClicked();
              },
              label: (step == BroadcastTxStep.import) ? 'Decode' : 'Broadcast',
            ),
          ),
        ),
      ],
    );
  }
}
