import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/screens/exchange_sceen.dart';
import 'package:bb_mobile/features/home/ui/screens/wallets_screen.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/navbar/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (context) => locator<HomeBloc>()..add(const HomeStarted()),
      child: BlocListener<SettingsCubit, SettingsEntity?>(
        listenWhen:
            (previous, current) =>
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
    final page = context.select((HomeBloc bloc) => bloc.state.selectedTab);
    return Scaffold(
      bottomNavigationBar: BottomNavbar(
        selectedPage: page.index,
        onPageSelected: (index) {
          context.read<HomeBloc>().add(ChangeHomeTab(HomeTabs.values[index]));
        },
      ),
      body: switch (page) {
        HomeTabs.wallets => const HomeWalletsScreen(),
        HomeTabs.exchange => const HomeExchangeScreen(),
      },
    );
  }
}
