import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/home/presentation/view_models/wallet_card_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class BitcoinWalletCard extends StatelessWidget {
  const BitcoinWalletCard();

  @override
  Widget build(BuildContext context) {
    final walletCardModel = context.select(
      (HomeBloc bloc) => bloc.state.maybeWhen(
        success: (_, bitcoinWalletCard, __) => bitcoinWalletCard,
        orElse: () => null,
      ),
    );

    return WalletCard(
      color: Colors.orange,
      walletCardModel: walletCardModel,
    );
  }
}

class LiquidWalletCard extends StatelessWidget {
  const LiquidWalletCard();

  @override
  Widget build(BuildContext context) {
    final walletCardModel = context.select(
      (HomeBloc bloc) => bloc.state.maybeWhen(
        success: (liquidWalletCard, _, __) => liquidWalletCard,
        orElse: () => null,
      ),
    );

    return WalletCard(
      color: Colors.yellow,
      walletCardModel: walletCardModel,
    );
  }
}

class WalletCard extends StatelessWidget {
  final Color color;
  final WalletCardViewModel? walletCardModel;

  const WalletCard({
    required this.color,
    this.walletCardModel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: walletCardModel == null
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    walletCardModel!.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    walletCardModel!.balanceSat.toString(),
                    style: const TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    walletCardModel!.network.name,
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
