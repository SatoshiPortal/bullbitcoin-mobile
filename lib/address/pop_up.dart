import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/launcher.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/_ui/inline_label.dart';
import 'package:bb_mobile/address/bloc/address_cubit.dart';
import 'package:bb_mobile/address/bloc/address_state.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

class AddressPopUp extends StatelessWidget {
  const AddressPopUp({super.key});

  static Future openPopup(
    BuildContext context,
    Address address,
  ) async {
    final settings = context.read<SettingsCubit>();
    final wallet = context.read<WalletBloc>();
    final walletSettings = context.read<WalletSettingsCubit>();
    final addressCubit = AddressCubit(
      address: address,
      walletAddress: locator<WalletAddress>(),
      walletBloc: wallet,
    );

    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: wallet),
          BlocProvider.value(value: walletSettings),
          BlocProvider.value(value: addressCubit),
        ],
        child: const AddressPopUp(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _Screen();
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BBHeader.popUpCenteredText(
            text: 'Address',
          ),
          const Title(),
          const AddressQR(),
          const Gap(8),
          Divider(
            color: context.colour.onBackground.withOpacity(0.3),
          ),
          const Gap(8),
          const AddressDetails(),
          const Gap(4),
          Divider(
            color: context.colour.onBackground.withOpacity(0.3),
          ),
          const Gap(4),
          const AddressActions(),
          const Gap(40),
          const CopyButton(),
          const Gap(80),
        ],
      ),
    );
  }
}

class Title extends StatelessWidget {
  const Title({super.key});

  @override
  Widget build(BuildContext context) {
    final _ = context.select((AddressCubit cubit) => cubit.state.address!);
    final label = context.select((AddressCubit cubit) => cubit.state.address!.label ?? '');
    final address = context.select((AddressCubit cubit) => cubit.state.address!.miniString());

    final walletName = context.select((WalletBloc cubit) => cubit.state.wallet!.name ?? '');
    final walletFingerprint = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.sourceFingerprint,
    );
    final title = walletName.isEmpty ? walletFingerprint : walletName;

    return Center(
      child: Column(
        children: [
          BBText.body(
            label.isEmpty ? address : label,
          ),
          const Gap(8),
          BBText.title(
            'From wallet: ' + title,
          ),
        ],
      ),
    );
  }
}

class AddressQR extends StatelessWidget {
  const AddressQR({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select((AddressCubit cubit) => cubit.state.address!);
    final url = context.select(
      (NetworkCubit _) => _.state.explorerAddressUrl(address.address, isLiquid: address.isLiquid),
    );

    return Column(
      children: [
        const Gap(8),
        ColoredBox(
          color: Colors.white,
          child: QrImageView(
            data: address.address,
            padding: EdgeInsets.zero,
          ),
        ),
        const Gap(8),
        InkWell(
          onTap: () {
            locator<Launcher>().launchApp(url);
          },
          child: BBText.body(
            address.address,
            isBlue: true,
          ),
        ),
      ],
    );
  }
}

class AddressDetails extends StatelessWidget {
  const AddressDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final address = context.select((AddressCubit cubit) => cubit.state.address!);
    final label = address.label ?? '';
    final isReceive = address.kind == AddressKind.deposit;
    final balance = address.balance;
    final amt = context.select((CurrencyCubit cubit) => cubit.state.getAmountInUnits(balance));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        InlineLabel(
          title: 'Index',
          body: (address.index == null) ? 'N/A' : address.index.toString(),
        ),
        const Gap(8),
        InlineLabel(title: 'Balance', body: amt),
        if (label.isNotEmpty) ...[
          const Gap(8),
          InlineLabel(title: 'Label', body: label),
        ],
        const Gap(8),
        InlineLabel(
          title: 'Type',
          body: (isReceive ? 'Receive' : 'Change'),
        ),
        const Gap(8),
      ],
    );
  }
}

class AddressActions extends StatelessWidget {
  const AddressActions({super.key});

  @override
  Widget build(BuildContext context) {
    final bool frozen = context.select(
      (AddressCubit cubit) => cubit.state.address!.spendable == false,
    );
    final freezing = context.select((AddressCubit cubit) => cubit.state.freezingAddress);
    final hasUtxos = context.select((AddressCubit cubit) => cubit.state.address?.state == AddressStatus.active);
    //TODO: UTXO context.select((AddressCubit cubit) => cubit.state.address!.utxos?.isNotEmpty ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Gap(8),
        InkWell(
          onTap: () {
            AddressLabelFieldPopUp.openPopup(
              context,
              context.read<AddressCubit>().state.address!,
            );
          },
          child: const BBText.body(
            'Edit Label',
            isBlue: true,
          ),
        ),
        if (hasUtxos) ...[
          const Gap(8),
          InkWell(
            onTap: () {
              if (freezing) return;
              if (frozen)
                context.read<AddressCubit>().unfreezeAddress();
              else
                context.read<AddressCubit>().freezeAddress();
            },
            child: BBText.body(
              frozen ? 'Unfreeze address' : 'Freeze address',
              isBlue: true,
            ),
          ),
        ],
      ],
    );
  }
}

class CopyButton extends StatefulWidget {
  const CopyButton({super.key});

  @override
  State<CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final address = context.select((AddressCubit cubit) => cubit.state.address!);

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: _copied
            ? const Center(child: BBText.body('Address copied'))
            : SizedBox(
                width: 250,
                child: BBButton.big(
                  onPressed: () {
                    setState(() {
                      _copied = true;
                    });
                    if (locator.isRegistered<Clippboard>()) locator<Clippboard>().copy(address.address);

                    Future.delayed(const Duration(seconds: 2), () {
                      setState(() {
                        _copied = false;
                      });
                    });
                  },
                  label: 'Copy Address',
                ),
              ),
      ),
    );
  }
}

class AddressLabelFieldPopUp extends StatelessWidget {
  const AddressLabelFieldPopUp({super.key, required this.address});

  final Address address;

  static Future openPopup(
    BuildContext context,
    Address address,
  ) {
    final settings = context.read<SettingsCubit>();
    final wallet = context.read<WalletBloc>();
    final walletSettings = context.read<WalletSettingsCubit>();
    final addressCubit = context.read<AddressCubit>();

    return showBBBottomSheet(
      context: context,
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: settings),
          BlocProvider.value(value: wallet),
          BlocProvider.value(value: walletSettings),
          BlocProvider.value(value: addressCubit),
        ],
        child: BlocListener<AddressCubit, AddressState>(
          listenWhen: (previous, current) => previous.savedAddressName != current.savedAddressName,
          listener: (context, state) async {
            if (!state.savedAddressName) return;

            context.pop();
          },
          child: AddressLabelFieldPopUp(address: address),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(24),
          Row(
            children: [
              const Gap(8),
              const BBText.body(
                'Change address label',
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(FontAwesomeIcons.xmark),
                onPressed: () => context.pop(),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 8,
            ),
            child: BBText.body(
              'Address: ' + address.address,
            ),
          ),
          const Gap(24),
          AddressLabelTextField(address: address),
          const Gap(80),
        ],
      ),
    );
  }
}

class AddressLabelTextField extends StatefulWidget {
  const AddressLabelTextField({super.key, required this.address});

  final Address address;

  @override
  State<AddressLabelTextField> createState() => _AddressLabelTextFieldState();
}

class _AddressLabelTextFieldState extends State<AddressLabelTextField> {
  final _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final saving = context.select((AddressCubit cubit) => cubit.state.savingAddressName);
    final err = context.select((AddressCubit cubit) => cubit.state.errSavingAddressName);
    final saved = context.select((AddressCubit cubit) => cubit.state.savedAddressName);
    final _ = widget.address.label ?? 'Enter Label';

    if (saved) const Center(child: BBText.body('Saved!')).animate(delay: 300.ms).fadeIn();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: TextField(
            controller: _controller,
          ),
        ),
        const Gap(60),
        if (err.isNotEmpty) ...[
          BBText.body(
            err,
          ),
          const Gap(16),
        ],
        Center(
          child: SizedBox(
            width: 250,
            child: BBButton.big(
              loading: saving,
              onPressed: () {
                if (_controller.text.isEmpty) return;
                FocusScope.of(context).requestFocus(FocusNode());
                context.read<AddressCubit>().saveAddressName(widget.address, _controller.text);
              },
              label: 'Save',
            ),
          ),
        ),
      ],
    );
  }
}
