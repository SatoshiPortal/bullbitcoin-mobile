import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/receive/bloc/receive_cubit.dart';
import 'package:bb_mobile/receive/bloc/state.dart';
import 'package:bb_mobile/receive/wallet_select.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  late ReceiveCubit _cubit;
  @override
  void initState() {
    final wallet = context.read<SelectReceiveWalletStep>().state.walletBloc;
    if (wallet == null) return;

    _cubit = ReceiveCubit(
      walletBloc: wallet,
      walletAddress: locator<WalletAddress>(),
      hiveStorage: locator<HiveStorage>(),
      walletRepository: locator<WalletRepository>(),
      settingsCubit: locator<SettingsCubit>(),
      networkCubit: locator<NetworkCubit>(),
      currencyCubit: CurrencyCubit(
        hiveStorage: locator<HiveStorage>(),
        bbAPI: locator<BullBitcoinAPI>(),
        defaultCurrencyCubit: context.read<CurrencyCubit>(),
      ),
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _cubit),
        BlocProvider.value(value: _cubit.currencyCubit),
      ],
      child: const _Screen(),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(24),
            _WalletName(),
            QRDisplay(),
            DisplayAddress(),
            Gap(24),
            AddressDetails(),
            Actions(),
          ],
        ),
      ),
    );
  }
}

class AddressDetails extends StatelessWidget {
  const AddressDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final label = context.select((ReceiveCubit x) => x.state.privateLabel);
    final amount = context.select((ReceiveCubit x) => x.state.savedInvoiceAmount);
    final description = context.select((ReceiveCubit x) => x.state.savedDescription);
    final amountStr = context.select(
      (CurrencyCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        hideZero: true,
        isSats: true,
      ),
    );
    return Column(
      children: [
        if (label.isNotEmpty) ...[
          _DetailRow(
            text: label,
            onTap: () {
              RenameLabel.openPopUp(context);
            },
            title: 'Address Label',
          ),
        ] else ...[
          BBButton.textWithRightArrow(
            label: 'Address Label',
            onPressed: () {
              RenameLabel.openPopUp(context);
            },
          ),
        ],
        if (amount > 0) ...[
          _DetailRow(
            text: amountStr,
            onTap: () {
              CreateInvoice.openPopUp(context);
            },
            title: 'Amount Request',
          ),
        ],
        if (description.isNotEmpty) ...[
          _DetailRow(
            text: description,
            onTap: () {
              CreateInvoice.openPopUp(context);
            },
            title: 'Public Description',
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.text, required this.onTap, required this.title});

  final String text;
  final String title;
  final Function onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Align(alignment: Alignment.centerLeft, child: BBText.title(title)),
        Row(
          children: [
            BBText.body(text, isBold: true),
            const Gap(4),
            IconButton(
              iconSize: 16,
              onPressed: () {
                onTap();
              },
              icon: FaIcon(
                FontAwesomeIcons.penToSquare,
                color: context.colour.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class Actions extends StatelessWidget {
  const Actions({super.key});

  @override
  Widget build(BuildContext context) {
    final showRequestButton = context.select((ReceiveCubit x) => x.state.showNewRequestButton());
    final errLoadingAddress = context.select((ReceiveCubit x) => x.state.errLoadingAddress);

    return Column(
      children: [
        if (showRequestButton)
          BBButton.textWithRightArrow(
            label: 'Request a payment',
            onPressed: () {
              CreateInvoice.openPopUp(context);
            },
          ),
        BBButton.textWithRightArrow(
          label: 'Generate a new address',
          onPressed: () {
            context.read<ReceiveCubit>().generateNewAddress();
          },
        ),
        BBText.errorSmall(errLoadingAddress),
      ],
    );
  }
}

class _WalletName extends StatelessWidget {
  const _WalletName();

  @override
  Widget build(BuildContext context) {
    final loading = context.select((ReceiveCubit x) => x.state.loadingAddress);

    final walletName = context.select((ReceiveCubit x) => x.walletBloc.state.wallet?.name);

    final fingerprint =
        context.select((ReceiveCubit x) => x.walletBloc.state.wallet?.sourceFingerprint ?? '');

    return AnimatedContainer(
      duration: 500.ms,
      child: Center(
        child: loading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  BBText.body('Waiting for sync to complete ...'),
                  Gap(32),
                  SizedBox(
                    height: 8,
                    width: 8,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              )
            : BBText.titleLarge(
                walletName ?? fingerprint,
              ),
      ),
    );
  }
}

class QRDisplay extends StatelessWidget {
  const QRDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select((ReceiveCubit x) => x.state.getQRStr());

    return Center(
      child: GestureDetector(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: address));
          SystemSound.play(SystemSoundType.click);
          HapticFeedback.selectionClick();
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        },
        child: ColoredBox(
          color: Colors.white,
          child: QrImageView(
            data: address,
          ),
        ),
      ),
    );
  }
}

class DisplayAddress extends StatefulWidget {
  const DisplayAddress({super.key});

  @override
  State<DisplayAddress> createState() => _DisplayAddressState();
}

class _DisplayAddressState extends State<DisplayAddress> {
  bool showToast = false;

  void _copyClicked() async {
    if (!mounted) return;
    setState(() {
      showToast = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() {
      showToast = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final addressQr = context.select((ReceiveCubit x) => x.state.getQRStr());

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !showToast
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: BBText.body(
                    addressQr,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: addressQr));
                      SystemSound.play(SystemSoundType.click);
                      HapticFeedback.selectionClick();
                      _copyClicked();
                    },
                    iconSize: 30,
                    color: context.colour.secondary,
                    icon: const FaIcon(FontAwesomeIcons.copy),
                  ),
                ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: BBText.body('Address copied to clipboard'),
            ),
    );
  }
}

class CreateInvoice extends StatelessWidget {
  const CreateInvoice({super.key});

  static Future openPopUp(BuildContext context) async {
    final receiveCubit = context.read<ReceiveCubit>();
    final currencyCubit = context.read<CurrencyCubit>();
    // currencyCubit.reset();
    // currencyCubit.updateAmountDirect(receiveCubit.state.savedInvoiceAmount);
    // currencyCubit.updateAmount(receiveCubit.state.savedInvoiceAmount.toString());
    if (currencyCubit.state.amount > 0) currencyCubit.convertAmtOnCurrencyChange();

    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: receiveCubit,
        child: BlocProvider.value(
          value: currencyCubit,
          child: BlocListener<ReceiveCubit, ReceiveState>(
            listenWhen: (previous, current) =>
                previous.savedInvoiceAmount != current.savedInvoiceAmount ||
                previous.savedDescription != current.savedDescription,
            listener: (context, state) {
              context.pop();
            },
            child: const PopUpBorder(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CreateInvoice(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final description = context.select((ReceiveCubit _) => _.state.description);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBHeader.popUpCenteredText(text: 'Request a Payment'),
        const Gap(40),
        // const BBText.title('Amount'),
        const Gap(4),
        const EnterAmount(),
        const Gap(24),
        const BBText.title('   Public description'),
        const Gap(4),
        BBTextInput.big(
          value: description,
          hint: 'Enter description',
          onChanged: (txt) {
            context.read<ReceiveCubit>().descriptionChanged(txt);
          },
        ),
        const Gap(40),
        BBButton.bigRed(
          label: 'Save',
          onPressed: () {
            context.read<ReceiveCubit>().saveFinalInvoiceClicked();
          },
        ),
        const Gap(40),
      ],
    );
  }
}

class RenameLabel extends StatelessWidget {
  const RenameLabel({super.key});

  static Future openPopUp(BuildContext context) async {
    final receiveCubit = context.read<ReceiveCubit>();

    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: receiveCubit,
        child: BlocListener<ReceiveCubit, ReceiveState>(
          listenWhen: (previous, current) =>
              previous.defaultAddress?.label != current.defaultAddress?.label,
          listener: (context, state) {
            context.pop();
          },
          child: const PopUpBorder(
            child: Padding(
              padding: EdgeInsets.all(30),
              child: RenameLabel(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = context.select((ReceiveCubit _) => _.state.privateLabel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBHeader.popUpCenteredText(text: 'Address Label'),
        const Gap(40),
        const BBText.title('Address Label (Optional)'),
        const Gap(4),
        BBTextInput.big(
          value: label,
          hint: 'Enter Private Label',
          onChanged: (txt) {
            context.read<ReceiveCubit>().privateLabelChanged(txt);
          },
        ),
        const Gap(40),
        BBButton.bigRed(
          label: 'Save',
          onPressed: () {
            context.read<ReceiveCubit>().saveDefaultAddressLabel();
          },
        ),
        const Gap(40),
      ],
    );
  }
}
