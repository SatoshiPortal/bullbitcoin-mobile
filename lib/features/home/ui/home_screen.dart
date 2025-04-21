import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/features/exchange/ui/webview.dart';
import 'package:bb_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_bottom_buttons.dart';
import 'package:bb_mobile/features/home/ui/widgets/home_errors.dart';
import 'package:bb_mobile/features/home/ui/widgets/top_section.dart';
import 'package:bb_mobile/features/home/ui/widgets/wallet_cards.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/ui/components/navbar/bottom_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeBloc>(
      create: (context) => locator<HomeBloc>()..add(const HomeStarted()),
      child: BlocListener<SettingsCubit, SettingsState?>(
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

class _Screen extends StatefulWidget {
  const _Screen();

  @override
  State<_Screen> createState() => _ScreenState();
}

class _ScreenState extends State<_Screen> {
  int page = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavbar(
        selectedPage: page,
        onPageSelected: (index) {
          setState(() {
            page = index;
          });
        },
      ),
      body: page == 0
          ? const Column(
              children: [
                HomeTopSection(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        HomeErrors(),
                        HomeWalletCards(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 13.0),
                  child: HomeBottomButtons(),
                ),
                Gap(16),
              ],
            )
          : const BullBitcoinWebViewPage(),
    );
  }
}
