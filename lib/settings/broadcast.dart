import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/file_picker.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/wallet/bdk/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/repository/network.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_cubit.dart';
import 'package:bb_mobile/settings/bloc/broadcasttx_state.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class BroadcastPage extends StatelessWidget {
  const BroadcastPage({super.key});

  @override
  Widget build(BuildContext context) {
    final broadcast = BroadcastTxCubit(
      barcode: locator<Barcode>(),
      filePicker: locator<FilePick>(),
      // settingsCubit: locator<SettingsCubit>(),
      networkCubit: locator<NetworkCubit>(),
      fileStorage: locator<FileStorage>(),
      homeCubit: locator<HomeCubit>(),
      networkRepository: locator<NetworkRepository>(),
      bdkTransactions: locator<BDKTransactions>(),
    );

    return BlocProvider.value(
      value: broadcast,
      child: BlocListener<BroadcastTxCubit, BroadcastTxState>(
        listenWhen: (previous, current) => previous.sent != current.sent,
        listener: (context, state) async {
          if (state.sent) {
            await Future.delayed(3.seconds);

            if (!context.mounted) return;
            context.pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: BBAppBar(
              text: 'Broadcast',
              onBack: () {
                context.pop();
              },
            ),
          ),
          body: const SingleChildScrollView(
            child: _Screen(),
          ),
        ),
      ),
    );
  }
}

class BroadcastPopUp extends StatelessWidget {
  const BroadcastPopUp({super.key});

  static Future openPopUp(BuildContext context) {
    final broadcast = BroadcastTxCubit(
      barcode: locator<Barcode>(),
      filePicker: locator<FilePick>(),
      // settingsCubit: locator<SettingsCubit>(),
      networkCubit: locator<NetworkCubit>(),
      fileStorage: locator<FileStorage>(),
      homeCubit: locator<HomeCubit>(),
      networkRepository: locator<NetworkRepository>(),
      bdkTransactions: locator<BDKTransactions>(),
    );

    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: broadcast,
        child: BlocListener<BroadcastTxCubit, BroadcastTxState>(
          listenWhen: (previous, current) => previous.sent != current.sent,
          listener: (context, state) async {
            if (state.sent) {
              await Future.delayed(3.seconds);

              if (!context.mounted) return;
              context.pop();
            }
          },
          child: const BroadcastPopUp(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BBHeader.popUpCenteredText(
          text: 'BROADCAST',
          onBack: () {
            context.pop();
          },
          // isLeft: true,
        ),
        const Gap(16),
        const _Screen(),
      ],
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 32,
      ),
      child: BlocBuilder<BroadcastTxCubit, BroadcastTxState>(
        buildWhen: (previous, current) => previous.step != current.step,
        builder: (context, state) {
          final step = state.step;
          return BlocListener<BroadcastTxCubit, BroadcastTxState>(
            listenWhen: (previous, current) =>
                previous.hasErr() != current.hasErr() && current.hasErr(),
            listener: (context, state) async {},
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(16),
                if (step == BroadcastTxStep.broadcast) ...[
                  const TxInfo(),
                ] else ...[
                  const BBText.body('Import Transaction'),
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
                      child: BBButton.big(
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
                ],
                const Gap(80),
                const BroadcastSendButton(),
                const Gap(48),
              ],
            ),
          );
        },
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

class DownloadButton extends StatelessWidget {
  const DownloadButton({super.key});

  @override
  Widget build(BuildContext context) {
    final downloading =
        context.select((BroadcastTxCubit cubit) => cubit.state.downloadingFile);
    final downloaded =
        context.select((BroadcastTxCubit cubit) => cubit.state.downloaded);

    if (downloaded) {
      return Center(
        child: const BBText.body(
          'Downloaded',
        ).animate(delay: 300.ms).fadeIn(),
      );
    }

    return Center(
      child: SizedBox(
        width: 300,
        child: BBButton.big(
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

class BroadcastSendButton extends StatelessWidget {
  const BroadcastSendButton({super.key});

  @override
  Widget build(BuildContext context) {
    final step = context.select((BroadcastTxCubit cubit) => cubit.state.step);
    final _ = context.select((BroadcastTxCubit cubit) => cubit.state.hasErr());
    final __ =
        context.select((BroadcastTxCubit cubit) => cubit.state.getErrors());

    final broadcasting =
        context.select((BroadcastTxCubit cubit) => cubit.state.broadcastingTx);
    final extractingTx =
        context.select((BroadcastTxCubit cubit) => cubit.state.extractingTx);
    final loading = broadcasting || extractingTx;

    final sent = context.select((BroadcastTxCubit cubit) => cubit.state.sent);
    final signed =
        context.select((BroadcastTxCubit cubit) => cubit.state.isSigned);

    if (sent) {
      return const Center(
        child: BBText.body(
          'Tx Broadcasted!',
        ),
      ).animate(delay: 300.ms).fadeIn();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // if (hasErr) ...[
        //   BBText.error(
        //     err,
        //   ),
        //   const Gap(16),
        // ],
        Center(
          child: SizedBox(
            width: 300,
            child: BBButton.big(
              loading: loading,
              onPressed: () {
                // if (loading) return;
                if (step == BroadcastTxStep.import) {
                  context.read<BroadcastTxCubit>().extractTxClicked();
                }
                if (step == BroadcastTxStep.broadcast && signed) {
                  context.read<BroadcastTxCubit>().broadcastClicked();
                }
              },
              label: (step == BroadcastTxStep.import) ? 'Decode' : 'Broadcast',
            ),
          ),
        ),
      ],
    );
  }
}

class TxInfo extends StatelessWidget {
  const TxInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final bState = context.select((BroadcastTxCubit cubit) => cubit.state);

    final tx =
        context.select((BroadcastTxCubit cubit) => cubit.state.transaction);
    // final psbt = context.select((BroadcastTxCubit cubit) => cubit.state.psbtBDK);
    if (tx == null) return const SizedBox();
    final String label = tx.label ?? 'No Labels';

    final txamt = context.select(
      (BroadcastTxCubit cubit) => cubit.state.amount ?? 0,
    );
    final signed =
        context.select((BroadcastTxCubit cubit) => cubit.state.isSigned);

    final txfee = context
        .select((BroadcastTxCubit cubit) => cubit.state.transaction?.fee ?? 0);
    // final txAddress = context.select((BroadcastTxCubit _) => _.state.transaction?.outAddrs ?? []);
    final cState = context.select((CurrencyCubit cubit) => cubit.state);
    final amt = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(txamt));
    final fee = context
        .select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(txfee));
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // const Gap(24),
          if (bState.recognizedTx == true) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  transformAlignment: Alignment.center,
                  child: const FaIcon(
                    FontAwesomeIcons.shield,
                    size: 12,
                  ),
                ),
                const Gap(8),
                const BBText.bodySmall(
                  'Verified: Local transaction detected',
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [BBText.bodySmall('Labels: $label')],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  transformAlignment: Alignment.center,
                  child: const FaIcon(
                    FontAwesomeIcons.commentDots,
                    size: 12,
                  ),
                ),
                const Gap(8),
                const BBText.bodySmall(
                  'Unverified: Transaction not found locally.',
                ),
              ],
            ),
          ],
          const Gap(8),
          // const Gap(24),
          if (signed == true) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  transformAlignment: Alignment.center,
                  child: const FaIcon(
                    FontAwesomeIcons.signature,
                    size: 12,
                  ),
                ),
                const Gap(8),
                const BBText.bodySmall(
                  'Signed',
                ),
              ],
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Container(
                  transformAlignment: Alignment.center,
                  child: const FaIcon(
                    FontAwesomeIcons.signature,
                    size: 12,
                  ),
                ),
                const Gap(8),
                const BBText.bodySmall(
                  'Unsigned',
                ),
              ],
            ),
          ],
          const Gap(8),
          const BBText.title('Total output amount'),
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
          if (bState.recognizedTx == true) ...[
            const Gap(24),
            const BBText.title(
              'Network Fee',
            ),
            const Gap(4),
            BBText.body(
              fee,
            ),
          ],
          const Gap(24),

          const BBText.title(
            'Outputs',
          ),
          const Gap(4),
          for (final address in tx.outAddrs) ...[
            BBText.body(
              '${address.getKindString()}:',
            ),
            const Gap(8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BBText.bodySmall(address.miniString()),
                BBText.bodyBold(
                  cState.getAmountInUnits(address.highestPreviousBalance),
                ),
              ],
            ),
            const Gap(8),
          ],

          // const DownloadButton(),
          // const Gap(16),
          // const Center(
          //   child: BBText.body(
          //     'Scan Txn',
          //   ),
          // ),
          // Center(
          //   child: SizedBox(
          //     width: 200,
          //     height: 200,
          //     child: QrImageView(data: psbtStr),
          //   ),
          // ),
          // const Gap(60),
          // const SendButton(),
          // const Gap(48),
        ],
      ),
    );
  }
}
