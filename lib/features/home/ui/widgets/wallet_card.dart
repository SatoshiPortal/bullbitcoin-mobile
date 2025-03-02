import 'package:bb_mobile/core/domain/entities/wallet.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitcoinWalletCard extends StatelessWidget {
  const BitcoinWalletCard();

  @override
  Widget build(BuildContext context) {
    final wallet = context.select(
      (HomeBloc bloc) => bloc.state.defaultBitcoinWallet,
    );

    return WalletCard(
      color: Colors.orange,
      wallet: wallet,
    );
  }
}

class LiquidWalletCard extends StatelessWidget {
  const LiquidWalletCard();

  @override
  Widget build(BuildContext context) {
    final wallet = context.select(
      (HomeBloc bloc) => bloc.state.defaultLiquidWallet,
    );

    return WalletCard(
      color: Colors.yellow,
      wallet: wallet,
    );
  }
}

class WalletCard extends StatelessWidget {
  final Color color;
  final Wallet? wallet;

  const WalletCard({
    required this.color,
    this.wallet,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wallet == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet!.label.isNotEmpty
                        ? wallet!.label
                        : wallet!.isDefault
                            ? wallet!.network.isBitcoin
                                ? 'Secure Bitcoin Wallet' // Todo: use localization label here
                                : 'Instant Payments Wallet' // Todo: use localization label here
                            : wallet!.id,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wallet!.balanceSat.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    wallet!.network.name,
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
