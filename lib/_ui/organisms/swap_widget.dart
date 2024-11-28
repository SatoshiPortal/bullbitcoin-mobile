import 'package:bb_mobile/_model/currency_new.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/molecules/currency_input_widget.dart';
import 'package:bb_mobile/_ui/molecules/wallet/wallet_dropdown.dart';
import 'package:bb_mobile/settings/bloc/lighting_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

const SATS_IN_BTC = 100000000;

final btcCurrencies = [
  btcCurrency,
  satsCurrency,
];

final lBtcCurrencies = [
  lbtcCurrency,
  lsatsCurrency,
];

class SwapWidget extends StatefulWidget {
  const SwapWidget({
    super.key,
    this.loading = false,
    required this.wallets,
    this.fromWalletId,
    this.toWalletId,
    this.onChange,
    this.onSwapPressed,
    this.swapButtonLabel = 'Swap',
    this.swapButtonLoadingLabel = 'Pls wait...',
    this.unitInSats = true,
    this.hideFromWallet = false,
    this.hideToWallet = false,
    this.fee,
    this.feeFiat,
  });

  final bool loading;
  final List<Wallet> wallets;
  final String? fromWalletId;
  final String? toWalletId;
  final Function(Wallet from, Wallet to, int amount, bool sweep)? onChange;
  final Function(Wallet from, Wallet to, int amount, bool sweep)? onSwapPressed;
  final String swapButtonLabel;
  final String swapButtonLoadingLabel;
  final bool unitInSats;
  final bool hideFromWallet;
  final bool hideToWallet;
  final String? fee;
  final String? feeFiat;

  @override
  State<SwapWidget> createState() => _SwapWidgetState();
}

class _SwapWidgetState extends State<SwapWidget> {
  List<Wallet> fromWallets = [];
  List<Wallet> toWallets = [];

  late Wallet selectedFromWallet;
  late Wallet selectedToWallet;

  TextEditingController fromPriceController = TextEditingController();
  TextEditingController toPriceController = TextEditingController();

  String fromPrice = '';
  String toPrice = '';

  CurrencyNew fromPriceCurrency = lBtcCurrencies[0];
  CurrencyNew toPriceCurrency = btcCurrencies[0];

  List<CurrencyNew> fromPriceCurrencies = lBtcCurrencies;
  List<CurrencyNew> toPriceCurrencies = btcCurrencies;

  bool sweep = false;

  @override
  void initState() {
    super.initState();

    fromWallets = widget.wallets;
    if (widget.fromWalletId != null) {
      final fromWallet =
          widget.wallets.where((w) => w.id == widget.fromWalletId).first;
      final toWallet = widget.wallets
          .where((w) => w.baseWalletType != fromWallet.baseWalletType)
          .first;

      selectedFromWallet = fromWallet;
      selectedToWallet = toWallet;

      if (fromWallet.baseWalletType == BaseWalletType.Bitcoin) {
        toWallets =
            widget.wallets.where((wallet) => wallet.isLiquid()).toList();
      } else {
        toWallets =
            widget.wallets.where((wallet) => !wallet.isLiquid()).toList();
      }
    }
    if (widget.toWalletId != null) {
      final toWallet =
          widget.wallets.where((w) => w.id == widget.toWalletId).first;
      final fromWallet = widget.wallets
          .where((w) => w.baseWalletType != toWallet.baseWalletType)
          .first;

      selectedFromWallet = fromWallet;
      selectedToWallet = toWallet;

      if (toWallet.baseWalletType == BaseWalletType.Bitcoin) {
        fromWallets =
            widget.wallets.where((wallet) => wallet.isLiquid()).toList();
      } else {
        fromWallets =
            widget.wallets.where((wallet) => !wallet.isLiquid()).toList();
      }
    }

    if (widget.fromWalletId == null && widget.toWalletId == null) {
      selectedFromWallet = widget.wallets[0];

      toWallets = widget.wallets
          .where((wallet) => wallet.isLiquid() != selectedFromWallet.isLiquid())
          .toList();

      selectedToWallet = toWallets[0];
    }

    if (widget.unitInSats) {
      fromPriceCurrency = lBtcCurrencies[1];
      toPriceCurrency = btcCurrencies[1];
    }

    fromPriceController.addListener(() {
      toPriceController.text = fromPriceController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.select(
      (Lighting x) => x.state.currentTheme(context) == ThemeMode.dark,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (widget.hideFromWallet == false) ...[
          const Text('Swap from'),
          const SizedBox(
            height: 4,
          ),
          WalletDropDown(
            showSpendableBalance: true,
            items: fromWallets,
            onChanged: _fromWalletChanged,
            value: selectedFromWallet,
          ),
          const SizedBox(
            height: 20,
          ),
        ],
        if (widget.hideToWallet == false) ...[
          const Text('Swap to'),
          const SizedBox(
            height: 4,
          ),
          WalletDropDown(
            items: toWallets,
            value: selectedToWallet,
            onChanged: _toWalletChanged,
          ),
          const SizedBox(
            height: 32,
          ),
        ],
        CurrencyInput(
          currencies: fromPriceCurrencies,
          currency: fromPriceCurrency,
          unitsInSats: widget.unitInSats,
          onlyCrypto: true,
          textEditingController: fromPriceController,
          label: 'Swap amount',
          sweepLabel: 'Swap entire balance',
          onChange: (sats, sweep, selectedCurrency) {
            _onChange(
              selectedFromWallet,
              selectedToWallet,
              sweep,
              sats: sats,
            );
          },
          onCurrencyChange: _fromCurrencyChanged,
          disabled: widget.loading,
        ),
        if (widget.fee != null)
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  height: 20,
                ),
                const BBText.title(
                  'Network Fee',
                ),
                const Gap(4),
                BBText.body(
                  widget.fee!,
                ),
                BBText.body(
                  widget.feeFiat!,
                ),
              ],
            ),
          ),
        const Gap(20),
        Align(
          child: BBButton.big(
            label: widget.swapButtonLabel,
            onPressed: _swapButtonPressed,
            loading: widget.loading,
            disabled: widget.loading,
            loadingText: widget.swapButtonLoadingLabel,
          ),
        ),
      ],
    );
  }

  void _swapButtonPressed() {
    if (widget.onSwapPressed != null) {
      final isSat = fromPriceCurrency.code.contains('sats');

      int sats = 0;
      try {
        sats = isSat
            ? int.parse(fromPriceController.text)
            : (double.parse(fromPriceController.text) * SATS_IN_BTC).toInt();
      } catch (e) {
        sats = 0;
      }

      widget.onSwapPressed?.call(
        selectedFromWallet,
        selectedToWallet,
        sats,
        sweep,
      );
    }
  }

  void _onChange(
    Wallet fromWallet,
    Wallet toWallet,
    bool localSweep, {
    int? sats,
  }) {
    final isSat = fromPriceCurrency.code.contains('sats');

    int localSats = 0;
    if (localSweep == false) {
      try {
        localSats = isSat
            ? int.parse(fromPriceController.text)
            : (double.parse(fromPriceController.text) * SATS_IN_BTC).toInt();
      } on FormatException {
        localSats = 0;
      }
    }

    widget.onChange?.call(
      fromWallet,
      toWallet,
      sats ?? localSats,
      localSweep,
    );

    setState(() {
      sweep = localSweep;
    });
  }

  void _fromCurrencyChanged(CurrencyNew? value) {
    if (value != null && (fromPriceCurrency.code != value.code)) {
      final isSat = value.code.contains('sats');
      final isLiquid = value.code.startsWith('L-');

      CurrencyNew toPriceCurrencyLocal;

      if (isLiquid) {
        if (isSat) {
          toPriceCurrencyLocal = btcCurrencies[1];
        } else {
          toPriceCurrencyLocal = btcCurrencies[0];
        }
      } else {
        if (isSat) {
          toPriceCurrencyLocal = lBtcCurrencies[1];
        } else {
          toPriceCurrencyLocal = lBtcCurrencies[0];
        }
      }

      setState(() {
        fromPriceCurrency = value;
        toPriceCurrency = toPriceCurrencyLocal;
      });
    }
  }

  void _fromWalletChanged(Wallet wallet) {
    List<Wallet> toWalletsLocal = [];
    Wallet? selectedToWalletLocal;

    List<CurrencyNew> fromCurrencies = [];
    List<CurrencyNew> toCurrencies = [];

    if (wallet.isLiquid()) {
      toWalletsLocal = widget.wallets.where((w) => !w.isLiquid()).toList();
      selectedToWalletLocal = toWalletsLocal[0]; //widget.wallets[1];

      fromCurrencies = lBtcCurrencies;
      toCurrencies = btcCurrencies;
    } else {
      toWalletsLocal = widget.wallets.where((w) => w.isLiquid()).toList();
      // toWalletsLocal = [widget.wallets[0]];
      selectedToWalletLocal = toWalletsLocal[0]; // toWalletsLocal[0];

      fromCurrencies = btcCurrencies;
      toCurrencies = lBtcCurrencies;
    }

    final isSat = fromPriceCurrency.code.contains('sats');

    setState(() {
      selectedFromWallet = wallet;

      selectedToWallet = selectedToWalletLocal!;
      toWallets = toWalletsLocal;

      fromPriceCurrencies = fromCurrencies;
      toPriceCurrencies = toCurrencies;

      fromPriceCurrency = fromCurrencies[isSat ? 1 : 0];
      toPriceCurrency = toCurrencies[isSat ? 1 : 0];
    });

    _onChange(
      wallet,
      selectedToWallet,
      sweep,
    );
  }

  void _toWalletChanged(Wallet wallet) {
    setState(() {
      selectedToWallet = wallet;
    });
    _onChange(
      selectedFromWallet,
      wallet,
      false,
    );
  }
}
