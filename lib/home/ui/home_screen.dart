import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/home/ui/widgets/home_app_bar.dart';
import 'package:bb_mobile/home/ui/widgets/home_bottom_buttons.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/presentation/bloc/settings_cubit.dart';
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
        child: const _Screen(),
      ),
    );
  }
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: HomeAppBar(),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Stack(
            children: [
              // SingleChildScrollView(
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.stretch,
              //     children: [
              //       LiquidWalletCard(),
              //       BitcoinWalletCard(),
              //     ],
              //   ),
              // ),
              HomeBottomButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
