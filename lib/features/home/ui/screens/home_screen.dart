import 'package:bb_mobile/features/home/presentation/blocs/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/pages/home_exchange_page.dart';
import 'package:bb_mobile/features/home/ui/pages/home_wallets_page.dart';
import 'package:bb_mobile/ui/components/navbar/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
        HomeTabs.wallets => const HomeWalletsPage(),
        HomeTabs.exchange => const HomeExchangePage(),
      },
    );
  }
}
