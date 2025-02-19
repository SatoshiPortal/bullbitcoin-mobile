import 'package:bb_mobile/app_locator.dart';
import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/home/presentation/widgets/home_app_bar.dart';
import 'package:bb_mobile/features/home/presentation/widgets/home_bottom_buttons.dart';
import 'package:bb_mobile/features/home/presentation/widgets/wallet_card.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (context) => locator<HomeBloc>()..add(const HomeStarted()),
      child: BlocListener<SettingsCubit, Settings?>(
        listenWhen: (previous, current) =>
            previous?.environment != current?.environment,
        listener: (context, settings) {
          context.read<HomeBloc>().add(const HomeStarted());
        },
        child: Scaffold(
          appBar: const HomeAppBar(),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(
                children: [
                  const SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LiquidWalletCard(),
                        BitcoinWalletCard(),
                      ],
                    ),
                  ),
                  HomeBottomButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
