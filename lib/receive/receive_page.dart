import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/_ui/templates/headers.dart';
import 'package:bb_mobile/locator.dart';
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

class ReceiveScreen extends StatelessWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wallet = context.select((SelectReceiveWalletStep _) => _.state.walletBloc);

    if (wallet == null) return const SizedBox.shrink();

    final receiveCubit = ReceiveCubit(
      walletBloc: wallet,
      walletAddress: locator<WalletAddress>(),
      hiveStorage: locator<HiveStorage>(),
      walletRepository: locator<WalletRepository>(),
      settingsCubit: locator<SettingsCubit>(),
    );
    return BlocProvider.value(
      value: receiveCubit,
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
      (SettingsCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        hideZero: true,
        removeEndZeros: true,
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
              onPressed: () {
                onTap();
              },
              icon: const FaIcon(FontAwesomeIcons.penToSquare),
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
      child: QrImageView(
        data: address,
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
    final address = context.select((ReceiveCubit x) => x.state.defaultAddress);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !showToast
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  child: BBText.body(
                    address!.largeString(),
                    textAlign: TextAlign.justify,
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

    return showMaterialModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => BlocProvider.value(
        value: receiveCubit,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final amount = context.select((ReceiveCubit _) => _.state.invoiceAmount);
    final description = context.select((ReceiveCubit _) => _.state.description);

    final amtStr = context.select(
      (SettingsCubit cubit) => cubit.state.getAmountInUnits(
        amount,
        removeText: true,
        hideZero: true,
        removeEndZeros: true,
        isSats: true,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBHeader.popUpCenteredText(text: 'Request a Payment'),
        const Gap(40),
        const BBText.title('Amount'),
        BBAmountInput(
          btcFormatting: true,
          value: amtStr,
          onRightTap: () {},
          disabled: false,
          isSats: false,
          hint: 'Enter Amount',
          onChanged: (txt) {
            final clean = txt.replaceAll(',', '').replaceAll(' ', '');
            final amt = context.read<SettingsCubit>().state.getSatsAmount(clean, false);
            context.read<ReceiveCubit>().updateAmount(amt);
          },
        ),
        const Gap(16),
        const BBText.title('Public description'),
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

// class _Screen extends StatelessWidget {
//   const _Screen();

//   @override
//   Widget build(BuildContext context) {
//     final step = context.select((ReceiveCubit x) => x.state.step);
//     return SingleChildScrollView(
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 32),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             // const BBHeader.popUpCenteredText(
//             //   text: 'RECEIVE',
//             //   isLeft: true,
//             // ),
//             if (step == ReceiveStep.defaultAddress) ...[
//               const Gap(24),
//               const WalletName(),
//               const Gap(24),
//               const DefaultQR(),
//               const DefaultAddress(),
//               const Gap(48),
//               const Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 16),
//                 child: LastAddressPrivateLabelField(),
//               ),
//               const Gap(48),
//               const RequestAmountButton(),
//               const Gap(80),
//             ],
//             if (step == ReceiveStep.createInvoice) ...[
//               const Gap(24),
//               const BBText.body(
//                 'Create Invoice',
//               ),
//               const Gap(48),
//               const BBText.body('    Amount'),
//               const Gap(4),
//               const InvoiceAmountField(),
//               const Gap(32),
//               const BBText.body('    Description'),
//               const Gap(4),
//               const InvoiceDescriptionField(),
//               // const NewAddressPrivateLabelField(),
//               const Gap(69),
//               // const NewAddressPrivateSaveButton(),
//               const InvoiceSaveButton(),
//               const Gap(80),
//             ],
//             // if (step == ReceiveStep.enterPrivateLabel) ...[
//             //   const Gap(60),
//             //   const BBText.body('    Note to self (private)'),
//             //   const Gap(4),
//             //   const NewAddressPrivateLabelField(),
//             //   const Gap(69),
//             //   const NewAddressPrivateSaveButton(),
//             //   const Gap(80),
//             // ],
//             if (step == ReceiveStep.showInvoice) ...[
//               const Gap(48),
//               const WalletName(),
//               const Gap(8),
//               const InvoiceQR(),
//               const Gap(16),
//               const InvoiceAddress(),
//               const Gap(80),
//             ],
//             // const Gap(80),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class InvoiceQR extends StatelessWidget {
//   const InvoiceQR({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final address = context.select((ReceiveCubit x) => x.state.invoiceAddress);

//     return Center(
//       child: QrImageView(
//         data: address,
//         size: 200,
//       ),
//     );
//   }
// }

// class InvoiceAddress extends StatelessWidget {
//   const InvoiceAddress({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final address = context.select((ReceiveCubit x) => x.state.invoiceAddress);

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 32),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           SizedBox(
//             width: 128,
//             child: Wrap(
//               children: [
//                 BBText.body(address),
//               ],
//             ),
//           ),
//           IconButton(
//             onPressed: () async {
//               await Clipboard.setData(ClipboardData(text: address));
//               SystemSound.play(SystemSoundType.click);
//               HapticFeedback.selectionClick();
//               ScaffoldMessenger.of(context).showSnackBar(
//                 context.showToast('Copied'),
//               );
//             },
//             iconSize: 16,
//             color: context.colour.secondary,
//             icon: const FaIcon(FontAwesomeIcons.copy),
//           ),
//         ],
//       ),
//     );
//   }
// }

// class LastAddressPrivateLabelField extends StatefulWidget {
//   const LastAddressPrivateLabelField({super.key});

//   @override
//   State<LastAddressPrivateLabelField> createState() => _LastAddressPrivateLabelFieldState();
// }

// class _LastAddressPrivateLabelFieldState extends State<LastAddressPrivateLabelField> {
//   @override
//   Widget build(BuildContext context) {
//     final saving = context.select(
//       (ReceiveCubit x) => x.state.savingLabel,
//     );

//     final text = context.select(
//       (ReceiveCubit x) => x.state.privateLabel,
//     );

//     final name = context.select(
//       (ReceiveCubit x) => x.state.defaultAddress?.label,
//     );

//     final showSave = text.isNotEmpty && name != text;

//     return Row(
//       children: [
//         Expanded(
//           child: BBTextInput.big(
//             value: text,
//             hint: name ?? 'Enter name',
//             onChanged: (txt) {
//               context.read<ReceiveCubit>().privateLabelChanged(txt);
//             },
//           ),
//         ),
//         const Gap(4),
//         if (!saving)
//           IgnorePointer(
//             ignoring: !showSave,
//             child: AnimatedOpacity(
//               duration: 300.ms,
//               opacity: showSave ? 1 : 0.4,
//               child: BBButton.smallBlack(
//                 filled: true,
//                 onPressed: () {
//                   context.read<ReceiveCubit>().saveDefaultAddressLabel();
//                 },
//                 label: 'SAVE',
//               ),
//             ),
//           )
//         else
//           const Center(
//             child: CircularProgressIndicator(),
//           ),
//       ],
//     );
//   }
// }

// class ReceiveInvoicePopUp extends StatelessWidget {
//   const ReceiveInvoicePopUp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Container();
//   }
// }

// class InvoiceAmountField extends StatefulWidget {
//   const InvoiceAmountField({super.key});

//   @override
//   State<InvoiceAmountField> createState() => _InvoiceAmountFieldState();
// }

// class _InvoiceAmountFieldState extends State<InvoiceAmountField> {
//   final _controller = TextEditingController();
//   final FocusNode _focusNode = FocusNode();

//   @override
//   void dispose() {
//     _focusNode.dispose();
//     _controller.dispose();
//     super.dispose();
//   }

//   KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
//     final delete = event.logicalKey == LogicalKeyboardKey.backspace;
//     if (delete) context.read<ReceiveCubit>().updateAmount(0);
//     return KeyEventResult.ignored;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final isSats = context.select((SettingsCubit cubit) => cubit.state.unitsInSats);
//     final amount = context.select((ReceiveCubit cubit) => cubit.state.invoiceAmount);
//     final amountStr = context.select(
//       (SettingsCubit cubit) => cubit.state.getAmountInUnits(
//         amount,
//         removeText: true,
//         hideZero: true,
//         removeEndZeros: true,
//       ),
//     );

//     if (_controller.text != amountStr) {
//       _controller.text = amountStr;

//       if (isSats)
//         _controller.selection = TextSelection.fromPosition(
//           TextPosition(
//             offset: amountStr.length,
//           ),
//         );
//       else
//         _controller.selection = TextSelection.fromPosition(
//           TextPosition(
//             offset: _controller.text.length,
//           ),
//         );
//     }

//     return Focus(
//       focusNode: _focusNode,
//       onKeyEvent: (n, e) {
//         return _handleKeyEvent(n, e);
//       },
//       child: TextField(
//         controller: _controller,
//         decoration: InputDecoration(
//           border: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(80.0),
//           ),
//           filled: true,
//           fillColor: context.colour.onPrimary,
//           contentPadding: const EdgeInsets.only(left: 24),
//           hintText: 'Enter amount',
//           suffixIcon: isSats
//               ? IconButton(
//                   color: context.colour.secondary,
//                   onPressed: () {
//                     context.read<SettingsCubit>().toggleUnitsInSats();
//                   },
//                   icon: const FaIcon(
//                     FontAwesomeIcons.coins,
//                   ),
//                 )
//               : IconButton(
//                   color: context.colour.secondary,
//                   onPressed: () {
//                     context.read<SettingsCubit>().toggleUnitsInSats();
//                   },
//                   icon: const FaIcon(
//                     FontAwesomeIcons.bitcoin,
//                   ),
//                 ),
//         ),
//         keyboardType: const TextInputType.numberWithOptions(
//           decimal: true,
//         ),
//         onChanged: (txt) {
//           final aLen = _controller.text.length;
//           final tLen = txt.length;
//           if (aLen > tLen || (aLen - tLen).abs() > 2) {
//             context.read<ReceiveCubit>().updateAmount(0);
//             return;
//           }
//           final clean = txt.replaceAll(',', '');
//           final amt = context.read<SettingsCubit>().state.getSatsAmount(clean, null);
//           context.read<ReceiveCubit>().updateAmount(amt);
//         },
//         inputFormatters: [
//           if (!isSats)
//             ThousandsFormatter(
//               formatter: NumberFormat()
//                 ..maximumFractionDigits = 8
//                 ..minimumFractionDigits = 8
//                 ..turnOffGrouping(),
//               allowFraction: true,
//             ),
//         ],
//       ),
//     );
//   }
// }

// class InvoiceDescriptionField extends StatefulWidget {
//   const InvoiceDescriptionField({super.key});

//   @override
//   State<InvoiceDescriptionField> createState() => _InvoiceDescriptionFieldState();
// }

// class _InvoiceDescriptionFieldState extends State<InvoiceDescriptionField> {
//   @override
//   Widget build(BuildContext context) {
//     final text = context.select(
//       (ReceiveCubit x) => x.state.description,
//     );

//     return BBTextInput.big(
//       value: text,
//       hint: 'Enter amount',
//       onChanged: (txt) {
//         context.read<ReceiveCubit>().descriptionChanged(txt);
//       },
//     );
//   }
// }

// class InvoiceSaveButton extends StatelessWidget {
//   const InvoiceSaveButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: SizedBox(
//         width: 200,
//         child: BBButton.bigBlack(
//           filled: true,
//           onPressed: () {
//             context.read<ReceiveCubit>().saveFinalInvoiceClicked();
//           },
//           label: 'SAVE',
//         ),
//       ),
//     );
//   }
// }

// class NewAddressPrivateLabelField extends StatefulWidget {
//   const NewAddressPrivateLabelField({super.key});

//   @override
//   State<NewAddressPrivateLabelField> createState() => _NewAddressPrivateLabelFieldState();
// }

// class _NewAddressPrivateLabelFieldState extends State<NewAddressPrivateLabelField> {
//   final _controller = TextEditingController();
//   @override
//   Widget build(BuildContext context) {
//     final text = context.select(
//       (ReceiveCubit x) => x.state.privateLabel,
//     );
//     if (text != _controller.text) _controller.text = text;

//     return BBTextInput.big(
//       value: text,
//       hint: 'Enter Private Label',
//       onChanged: (txt) {
//         context.read<ReceiveCubit>().privateLabelChanged(txt);
//       },
//     );
//   }
// }

// // class NewAddressPrivateSaveButton extends StatelessWidget {
// //   const NewAddressPrivateSaveButton({super.key});

// //   @override
// //   Widget build(BuildContext context) {
// //     return Center(
// //       child: SizedBox(
// //         width: 200,
// //         child: BBButton.bigBlack(
// //           filled: true,
// //           onPressed: () {
// //             context.read<ReceiveCubit>().saveFinalInvoiceClicked();
// //           },
// //           label: 'SAVE',
// //         ),
// //       ),
// //     );
// //   }
// // }

// class ShareButton extends StatelessWidget {
//   const ShareButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return Center(
//       child: SizedBox(
//         width: 200,
//         child: BBButton.bigRed(
//           onPressed: () {
//             context.read<ReceiveCubit>().shareClicked();
//           },
//           label: 'Share',
//         ),
//       ),
//     );
//   }
// }

// class RequestAmountButton extends StatelessWidget {
//   const RequestAmountButton({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return BBButton.text(
//       onPressed: () {
//         context.read<ReceiveCubit>().invoiceClicked();
//       },
//       label: 'Request Amount',
//       centered: true,
//     );
//   }
// }
