import 'package:bb_mobile/_pkg/barcode.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/file_storage.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/hive.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/address.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/_pkg/wallet/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/create.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/repository.dart';
import 'package:bb_mobile/_pkg/wallet/sensitive/transaction.dart';
import 'package:bb_mobile/_pkg/wallet/transaction.dart';
import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/components/text_input.dart';
import 'package:bb_mobile/currency/amount_input.dart';
import 'package:bb_mobile/currency/bloc/currency_cubit.dart';
import 'package:bb_mobile/home/bloc/home_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/network/bloc/network_cubit.dart';
import 'package:bb_mobile/network_fees/bloc/network_fees_cubit.dart';
import 'package:bb_mobile/network_fees/popup.dart';
import 'package:bb_mobile/send/advanced.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SendPage2 extends StatelessWidget {
  const SendPage2({super.key});

  @override
  Widget build(BuildContext context) {
    final send = SendCubit(
      hiveStorage: locator<HiveStorage>(),
      secureStorage: locator<SecureStorage>(),
      walletAddress: locator<WalletAddress>(),
      walletTx: locator<WalletTx>(),
      walletSensTx: locator<WalletSensitiveTx>(),
      walletCreate: locator<WalletCreate>(),
      walletSensCreate: locator<WalletSensitiveCreate>(),
      barcode: locator<Barcode>(),
      settingsCubit: locator<SettingsCubit>(),
      bullBitcoinAPI: locator<BullBitcoinAPI>(),
      mempoolAPI: locator<MempoolAPI>(),
      fileStorage: locator<FileStorage>(),
      walletRepository: locator<WalletRepository>(),
      walletSensRepository: locator<WalletSensitiveRepository>(),
      networkCubit: locator<NetworkCubit>(),
      networkFeesCubit: NetworkFeesCubit(
        hiveStorage: locator<HiveStorage>(),
        mempoolAPI: locator<MempoolAPI>(),
        networkCubit: locator<NetworkCubit>(),
        defaultNetworkFeesCubit: context.read<NetworkFeesCubit>(),
      ),
      currencyCubit: CurrencyCubit(
        hiveStorage: locator<HiveStorage>(),
        bbAPI: locator<BullBitcoinAPI>(),
        defaultCurrencyCubit: context.read<CurrencyCubit>(),
      ),
    );

    final home = locator<HomeCubit>();
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = home.state.walletBlocsFromNetwork(network);

    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: send),
        BlocProvider.value(value: send.currencyCubit),
        BlocProvider.value(value: send.networkFeesCubit),
        BlocProvider.value(value: home),
        if (walletBlocs.isNotEmpty) BlocProvider.value(value: walletBlocs.first),
      ],
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: const TopBar(),
          automaticallyImplyLeading: false,
        ),
        body: const _WalletProvider(child: _Screen()),
      ),
    );
  }
}

class _WalletProvider extends StatelessWidget {
  const _WalletProvider({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final send = context.select((SendCubit _) => _.state.selectedWalletBloc);

    if (send == null) return child;
    return BlocProvider.value(value: send, child: child);
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Gap(32),
            WalletSelectionDropDown(),
            Gap(48),
            AddressField(),
            Gap(24),
            AmountField(),
            Gap(24),
            NetworkFees(),
            Gap(8),
            AdvancedOptions(),
            Gap(48),
            _SendButton(),
          ],
        ),
      ),
    );
  }
}

class TopBar extends StatelessWidget {
  const TopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BBAppBar(
      text: 'Send Bitcoin',
      onBack: () {
        context.pop();
      },
    );
  }
}

class WalletSelectionDropDown extends StatelessWidget {
  const WalletSelectionDropDown({super.key});

  @override
  Widget build(BuildContext context) {
    final network = context.select((NetworkCubit _) => _.state.getBBNetwork());
    final walletBlocs = context.select((HomeCubit _) => _.state.walletBlocsFromNetwork(network));
    final selectedWalletBloc = context.select((SendCubit _) => _.state.selectedWalletBloc);

    final walletBloc = selectedWalletBloc ?? walletBlocs.first;

    return Center(
      child: SizedBox(
        width: 250,
        height: 45,
        child: Material(
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(8),
          child: DropdownButtonFormField<WalletBloc>(
            padding: EdgeInsets.zero,
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            isExpanded: true,
            decoration: InputDecoration(
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: NewColours.lightGray,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              border: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: NewColours.lightGray,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: NewColours.offWhite,
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: NewColours.lightGray,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            value: walletBloc,
            onChanged: (value) {
              if (value == null) return;
              context.read<SendCubit>().updateSelectedWalletBloc(value);
            },
            items: walletBlocs.map((wallet) {
              final name = wallet.state.wallet!.name ?? wallet.state.wallet!.sourceFingerprint;
              return DropdownMenuItem<WalletBloc>(
                value: wallet,
                child: Center(
                  child: BBText.body(name),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class AddressField extends StatefulWidget {
  const AddressField({super.key});

  @override
  State<AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<AddressField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    final address = context.select((SendCubit cubit) => cubit.state.address);
    if (_controller.text != address) {
      _controller.text = address;
      // _focusNode.unfocus();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Bitcoin payment address or invoice'),
        const Gap(4),
        BBTextInput.bigWithIcon2(
          focusNode: _focusNode,
          hint: 'Enter address',
          value: address,
          rightIcon: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () async {
                  if (!locator.isRegistered<Clippboard>()) return;
                  final data = await locator<Clippboard>().paste();
                  if (data == null) return;
                  context.read<SendCubit>().updateAddress(data);
                },
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                color: context.colour.onBackground,
                icon: const FaIcon(FontAwesomeIcons.paste),
              ),
              IconButton(
                onPressed: () {
                  context.read<SendCubit>().scanAddress();
                },
                icon: FaIcon(
                  FontAwesomeIcons.barcode,
                  color: context.colour.onBackground,
                ),
              ),
            ],
          ),
          onChanged: (txt) {
            context.read<SendCubit>().updateAddress(txt);
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}

class AmountField extends StatelessWidget {
  const AmountField({super.key});

  @override
  Widget build(BuildContext context) {
    final sendAll = context.select((SendCubit cubit) => cubit.state.sendAllCoin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BBText.title('Amount to send'),
        const Gap(4),
        EnterAmount2(sendAll: sendAll),
      ],
    );
  }
}

class NetworkFees extends StatelessWidget {
  const NetworkFees({super.key});

  @override
  Widget build(BuildContext context) {
    return const SelectFeesButton();
  }
}

class AdvancedOptions extends StatelessWidget {
  const AdvancedOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final text = context.select((SendCubit cubit) => cubit.state.advancedOptionsButtonText());
    return BBButton.text(
      // centered: true,
      onPressed: () {
        AdvancedOptionsPopUp.openPopup(context);
      },
      label: text,
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton();

  @override
  Widget build(BuildContext context) {
    return const SendButton();
  }
}

class HighFeeWarning extends StatelessWidget {
  const HighFeeWarning({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class PaymentSent extends StatelessWidget {
  const PaymentSent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
