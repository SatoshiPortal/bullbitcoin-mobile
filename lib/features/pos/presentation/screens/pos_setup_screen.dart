import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/widgets/bottom_sheet/x.dart';
import 'package:bb_mobile/core/widgets/price_input/price_input.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/pos/pos_router.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class PosSetupScreen extends StatefulWidget {
  const PosSetupScreen({super.key});

  @override
  State<PosSetupScreen> createState() => _PosSetupScreenState();
}

class _PosSetupScreenState extends State<PosSetupScreen> {
  final _name = TextEditingController(text: 'Bull POS');
  String? _walletId;
  String? _currency;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final wallets = state.wallets;
        _walletId ??= wallets.isEmpty ? null : wallets.first.id;
        _currency ??=
            context.select((SettingsCubit cubit) => cubit.state.currencyCode) ??
            'CAD';
        final availableCurrencies = _availableCurrencies(context);
        final selectedWallet = wallets
            .where((wallet) => wallet.id == _walletId)
            .firstOrNull;
        return Scaffold(
          appBar: AppBar(title: const Text('POS Setup')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (state.isLoading) const LinearProgressIndicator(),
              if (state.error != null)
                ListTile(
                  leading: const Icon(Icons.error_outline),
                  title: Text(state.error!),
                ),
              DropdownButtonFormField<String>(
                initialValue: _walletId,
                decoration: const InputDecoration(
                  labelText: 'Settlement wallet',
                  prefixIcon: Icon(Icons.account_balance_wallet),
                ),
                items: [
                  for (final wallet in wallets)
                    DropdownMenuItem(
                      value: wallet.id,
                      child: Text(wallet.label ?? wallet.networkString),
                    ),
                ],
                onChanged: (value) => setState(() => _walletId = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Merchant name',
                  prefixIcon: Icon(Icons.store),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: availableCurrencies.isEmpty
                    ? null
                    : () => _selectCurrency(context, availableCurrencies),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Currency',
                    prefixIcon: Icon(Icons.payments),
                    suffixIcon: Icon(Icons.keyboard_arrow_down),
                  ),
                  child: Text(_currency ?? ''),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.publish),
                label: const Text('Create and Publish'),
                onPressed: selectedWallet == null || state.isLoading
                    ? null
                    : () => context.read<PosCubit>().setup(
                        wallet: selectedWallet,
                        name: _name.text.trim(),
                        currency: (_currency ?? 'CAD').toUpperCase(),
                      ),
              ),
              if (state.cashierUrl != null) ...[
                const SizedBox(height: 24),
                Center(
                  child: QrDisplayWidget(data: state.cashierUrl!, size: 220),
                ),
                const SizedBox(height: 12),
                SelectableText(state.cashierUrl!),
                const SizedBox(height: 16),
                FilledButton.icon(
                  icon: const Icon(Icons.link),
                  label: const Text('Pair Terminal'),
                  onPressed: () => context.pushNamed(PosRoute.pair.name),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<String> _availableCurrencies(BuildContext context) {
    final blocCurrencies = context.select(
      (BitcoinPriceBloc bloc) => bloc.state.availableCurrencies,
    );
    final currencies = [
      ...?blocCurrencies,
      for (final currency in FiatCurrency.values) currency.code,
      ?_currency,
    ].map((currency) => currency.toUpperCase()).toSet().toList()..sort();
    return currencies;
  }

  Future<void> _selectCurrency(
    BuildContext context,
    List<String> availableCurrencies,
  ) async {
    final selected = await BlurredBottomSheet.show<String?>(
      context: context,
      child: CurrencyBottomSheet(
        availableCurrencies: availableCurrencies,
        selectedValue: _currency ?? 'CAD',
      ),
    );
    if (selected != null && mounted) {
      setState(() => _currency = selected);
    }
  }
}
