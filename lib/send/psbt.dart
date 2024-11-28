import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PSBTPopUp extends StatelessWidget {
  const PSBTPopUp({super.key});

  static Future openPopUp(BuildContext context) {
    final send = context.read<SendCubit>();

    return showBBBottomSheet(
      context: context,
      child: BlocProvider.value(
        value: send,
        child: const PSBTPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tx = context.select((SendCubit cubit) => cubit.state.tx);
    final psbt = context.select((SendCubit cubit) => cubit.state.psbt);

    if (tx == null || psbt.isEmpty) return const SizedBox();

    // final outAddresses = context.select((SendCubit cubit) => cubit.state.tx?.outAddresses ?? []);

    final txamt = tx.getAmount();
    final isSats =
        context.select((CurrencyCubit cubit) => cubit.state.unitsInSats);
    final txfee = context.select((SendCubit cubit) => cubit.state.tx?.fee ?? 0);
    final toAddress = tx.toAddress ?? '';
    final label = tx.label;

    final amt = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        txamt,
        isSats: isSats,
      ),
    );
    final fee = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        txfee,
        isSats: isSats,
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const BBHeader.popUpCenteredText(
            text: 'Built tx',
          ),
          const Gap(16),
          const BBText.title(
            'Amount to Send',
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
                  size: 16,
                ),
              ),
              const Gap(8),
              BBText.titleLarge(
                amt,
                isBold: true,
              ),
            ],
          ),
          const Gap(16),
          const BBText.title(
            'Receipent Bitcoin Address',
          ),
          const Gap(4),
          InkWell(
            onTap: () {
              final url = context
                  .read<NetworkCubit>()
                  .state
                  .explorerAddressUrl(toAddress);
              locator<Launcher>().launchApp(url);
            },
            child: BBText.body(
              toAddress,
              isBlue: true,
            ),
          ),
          const Gap(16),
          // if (outAddresses.isNotEmpty) ...[
          //   const BBText.title('Sender Bitcoin Addresses'),
          //   const Gap(4),
          //   for (final address in outAddresses) ...[
          //     BBButton.text(
          //       onPressed: () {
          //         final url = context.read<SettingsCubit>().state.explorerAddressUrl(address);
          //         locator<Launcher>().launchApp(url);
          //       },
          //       label: address,
          //     ),
          //     const Gap(4),
          //     Divider(color: context.colour.surface.withOpacity(0.2))
          //   ],
          //   const Gap(24),
          // ],
          const BBText.title(
            'Status',
          ),
          const Gap(4),
          const BBText.titleLarge(
            'Unsigned',
            isBold: true,
          ),
          const Gap(16),
          const BBText.title(
            'Network Fee',
          ),
          const Gap(4),
          BBText.titleLarge(
            fee,
            isBold: true,
          ),
          if (label != null && label.isNotEmpty) ...[
            const BBText.title(
              'Label',
            ),
            const Gap(4),
            BBText.titleLarge(
              label,
              isBold: true,
            ),
            const Gap(24),
          ],
          const Gap(32),
          const DownloadButton(),
          const Gap(32),
          const Center(
            child: BBText.body(
              'Scan PSBT',
            ),
          ),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: QrImageView(data: psbt),
            ),
          ),
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
    final downloading =
        context.select((SendCubit cubit) => cubit.state.downloadingFile);
    final downloaded =
        context.select((SendCubit cubit) => cubit.state.downloaded);
    // final walletType = context.select((WalletBloc _) => _.state.wallet!);
    if (downloaded) {
      return Column(
        children: [
          Center(
            child: const BBText.body(
              'Downloaded',
            ).animate(delay: 300.ms).fadeIn(),
          ),
          Center(
            child: const BBText.error(
              'ColdCard Notice: Wait for a moment for psbt to load into vdisk...',
            ).animate(delay: 300.ms).fadeIn(),
          ),
        ],
      );
    }
    // if (walletType == BBWalletType.coldcard) {

    // }
    return Center(
      child: SizedBox(
        width: 250,
        child: BBButton.big(
          filled: true,
          loading: downloading,
          loadingText: 'Downloading',
          onPressed: () {
            context.read<SendCubit>().downloadPSBTClicked();
          },
          label: 'DOWNLOAD FILE',
        ),
      ),
    );
  }
}
