import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/pos/pos_router.dart';
import 'package:bb_mobile/features/pos/presentation/bloc/pos_cubit.dart';
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
  final _currency = TextEditingController(text: 'CAD');
  String? _walletId;

  @override
  void dispose() {
    _name.dispose();
    _currency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final wallets = state.wallets;
        _walletId ??= wallets.isEmpty ? null : wallets.first.id;
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
              TextField(
                controller: _currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.payments),
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
                        currency: _currency.text.trim().toUpperCase(),
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
}
