import 'dart:io';

import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_auth_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_home_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_kyc_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_landing_screen_v2.dart';
import 'package:bb_mobile/features/exchange/ui/screens/exchange_support_login_screen.dart';
import 'package:bb_mobile/features/exchange_support_chat/ui/exchange_support_chat_router.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum ExchangeRoute {
  exchangeHome('/exchange'),
  exchangeLanding('/exchange/landing'),
  exchangeLoginForSupport('/exchange/login-support'),
  exchangeAuth('/exchange/auth'),
  exchangeKyc('kyc');

  final String path;

  const ExchangeRoute(this.path);
}

class ExchangeRouter {
  static final routes = [
    GoRoute(
      name: ExchangeRoute.exchangeHome.name,
      path: ExchangeRoute.exchangeHome.path,
      redirect: (context, state) {
        final notLoggedIn = context.read<ExchangeCubit>().state.notLoggedIn;
        if (notLoggedIn) {
          return ExchangeRoute.exchangeLanding.path;
        }
        final isSuperuser =
            context.read<SettingsCubit>().state.isSuperuser ?? false;
        if (Platform.isIOS && !isSuperuser) {
          return WalletRoute.walletHome.path;
        }
        return null;
      },
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const ExchangeHomeScreen(),
        );
      },
      routes: [
        GoRoute(
          name: ExchangeRoute.exchangeKyc.name,
          path: ExchangeRoute.exchangeKyc.path,
          builder: (context, state) {
            return const ExchangeKycScreen();
          },
        ),
      ],
    ),
    GoRoute(
      name: ExchangeRoute.exchangeLanding.name,
      path: ExchangeRoute.exchangeLanding.path,
      pageBuilder: (context, state) {
        // Show v2 screen for iOS without superuser, v1 for iOS with superuser, regular screen for Android
        Widget landingScreen;
        if (Platform.isIOS) {
          final isSuperuser =
              context.read<SettingsCubit>().state.isSuperuser ?? false;
          if (isSuperuser) {
            landingScreen = const ExchangeLandingScreen();
          } else {
            landingScreen = const ExchangeLandingScreenV2();
          }
        } else {
          landingScreen = const ExchangeLandingScreen();
        }

        return NoTransitionPage(key: state.pageKey, child: landingScreen);
      },
    ),
    GoRoute(
      name: ExchangeRoute.exchangeLoginForSupport.name,
      path: ExchangeRoute.exchangeLoginForSupport.path,
      pageBuilder: (context, state) {
        return NoTransitionPage(
          key: state.pageKey,
          child: const ExchangeSupportLoginScreen(),
        );
      },
    ),
    ExchangeSupportChatRouter.route,
    GoRoute(
      name: ExchangeRoute.exchangeAuth.name,
      path: ExchangeRoute.exchangeAuth.path,
      pageBuilder: (context, state) {
        final fromSupport =
            state.uri.queryParameters['from'] == 'support';
        return NoTransitionPage(
          key: state.pageKey,
          child: BlocListener<ExchangeCubit, ExchangeState>(
            listenWhen: (previous, current) =>
                previous.notLoggedIn && !current.notLoggedIn,
            listener: (context, exchangeState) {
              if (fromSupport) {
                final isIOSNonSuperuser = Platform.isIOS &&
                    !(context.read<SettingsCubit>().state.isSuperuser ?? false);
                context.goNamed(
                  ExchangeSupportChatRoute.supportChat.name,
                  queryParameters:
                      isIOSNonSuperuser ? {} : {'from': 'exchange'},
                );
                return;
              }
              final isSuperuser =
                  context.read<SettingsCubit>().state.isSuperuser ?? false;
              if (Platform.isIOS && !isSuperuser) {
                context.goNamed(WalletRoute.walletHome.name);
                return;
              }
              context.goNamed(ExchangeRoute.exchangeHome.name);
            },
            child: const ExchangeAuthScreen(),
          ),
        );
      },
    ),
  ];
}
