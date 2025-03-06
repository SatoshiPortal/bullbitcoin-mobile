import 'dart:async';

import 'package:bb_mobile/_model/swap.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_ui/logger_page.dart';
import 'package:bb_mobile/auth/page.dart';
import 'package:bb_mobile/create/page.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/home/market.dart';
import 'package:bb_mobile/home/transactions.dart';
import 'package:bb_mobile/import/hardware_page.dart';
import 'package:bb_mobile/import/page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/receive/receive_page.dart';
import 'package:bb_mobile/recoverbull/backup_key.dart';
import 'package:bb_mobile/recoverbull/backup_settings.dart';
import 'package:bb_mobile/recoverbull/encrypted_vault_backup.dart';
import 'package:bb_mobile/recoverbull/keychain_page.dart';
import 'package:bb_mobile/recoverbull/physical_backup.dart';
import 'package:bb_mobile/recoverbull/test_backup.dart';
import 'package:bb_mobile/send/bloc/send_cubit.dart';
import 'package:bb_mobile/send/send_page.dart';
import 'package:bb_mobile/settings/application_settings_page.dart';
import 'package:bb_mobile/settings/bitcoin_settings_page.dart';
import 'package:bb_mobile/settings/broadcast.dart';
import 'package:bb_mobile/settings/core_wallet_settings_page.dart';
import 'package:bb_mobile/settings/settings_page.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/swap/create_swap_bloc/swap_cubit.dart';
import 'package:bb_mobile/swap/receive.dart';
import 'package:bb_mobile/swap/swap_confirmation.dart';
import 'package:bb_mobile/swap/swap_history_page.dart';
import 'package:bb_mobile/swap/swap_page.dart';
import 'package:bb_mobile/swap/swap_page_progress_page.dart';
import 'package:bb_mobile/transaction/bump_fees.dart';
import 'package:bb_mobile/transaction/transaction_page.dart';
import 'package:bb_mobile/wallet/details.dart';
import 'package:bb_mobile/wallet/information_page.dart';
import 'package:bb_mobile/wallet/wallet_page.dart';
import 'package:bb_mobile/wallet_settings/accounting.dart';
import 'package:bb_mobile/wallet_settings/wallet_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:recoverbull/recoverbull.dart';

final navigatorKey = GlobalKey<NavigatorState>();

GoRouter setupRouter() => GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      observers: [GoRouterObserver()],
      routes: <RouteBase>[
        // GoRoute(
        //   path: '/testground',
        //   builder: (context, state) {
        //     return const Testground();
        //   },
        // ),
        GoRoute(
          path: '/',
          builder: (context, state) {
            return const AuthPage(fromSettings: false);
          },
        ),

        GoRoute(
          path: '/change-pin',
          builder: (context, state) {
            return const AuthPage(fromSettings: true);
          },
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) {
            // return const HomePage2();
            return const HomePage();
          },
        ),
        GoRoute(
          path: '/create-wallet',
          builder: (context, state) {
            return const CreateWalletPage();
          },
        ),
        GoRoute(
          path: '/import',
          builder: (context, state) {
            return const ImportWalletPage(isRecovery: true);
          },
        ),

        GoRoute(
          path: '/hardware-import',
          builder: (context, state) {
            return const HardwareImportPage();
          },
        ),
        GoRoute(
          path: '/recover',
          builder: (context, state) {
            return const ImportWalletPage(isRecovery: true);
          },
        ),
        // GoRoute(
        //   path: '/seed-view',
        //   builder: (context, state) {
        //     return const SeedViewPage();
        //   },
        // ),
        GoRoute(
          path: '/create-wallet-main',
          builder: (context, state) {
            scheduleMicrotask(() async {
              await Future.delayed(100.ms);

              if (!context.mounted) return;
              SystemChrome.setSystemUIOverlayStyle(
                SystemUiOverlayStyle(
                  statusBarColor: context.colour.surface,
                ),
              );
            });
            return const CreateWalletPage(mainWallet: true);
          },
        ),
        GoRoute(
          path: '/import-main',
          builder: (context, state) {
            scheduleMicrotask(() async {
              await Future.delayed(100.ms);

              if (!context.mounted) return;
              SystemChrome.setSystemUIOverlayStyle(
                SystemUiOverlayStyle(
                  statusBarColor: context.colour.surface,
                ),
              );
            });
            return const ImportWalletPage(
              mainWallet: true,
              isRecovery: true,
            );
          },
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) {
            return const SettingsPage();
          },
        ),
        GoRoute(
          path: '/bitcoin-settings',
          builder: (context, state) {
            return const BitcoinSettingsPage();
          },
        ),
        GoRoute(
          path: '/application-settings',
          builder: (context, state) {
            return const ApplicationSettingsPage();
          },
        ),
        GoRoute(
          path: '/core-wallet-settings',
          builder: (context, state) {
            return const CoreWalletSettingsPage();
          },
        ),
        GoRoute(
          path: '/information',
          builder: (context, state) {
            return const InformationPage();
          },
        ),

        GoRoute(
          path: '/tx',
          builder: (context, state) {
            // TODO: Convert this to proper map
            final list = state.extra! as List;
            final tx = list[0] as Transaction;
            final showOnchainSwap = list[1] as bool;

            // final tx = state.extra! as Transaction;
            return TxPage(
              tx: tx,
              showOnchainSwap: showOnchainSwap,
            );
          },
        ),
        GoRoute(
          path: '/wallet-settings',
          builder: (context, state) {
            final wallet = state.extra! as String;
            return WalletSettingsPage(wallet: wallet);
          },
          routes: [
            GoRoute(
              path: 'backup-settings',
              builder: (context, state) => BackupSettings(
                wallet: state.extra! as String,
              ),
              routes: [
                GoRoute(
                  path: 'backup-options',
                  builder: (context, state) => BackupOptionsScreen(
                    wallet: state.extra! as String,
                  ),
                  routes: [
                    GoRoute(
                      path: 'physical',
                      builder: (context, state) => PhysicalBackupPage(
                        wallet: state.extra! as String,
                      ),
                      routes: [
                        GoRoute(
                          path: 'test-backup',
                          builder: (context, state) {
                            final wallet = state.extra! as String;
                            return TestBackupPage(
                              wallet: wallet,
                              // walletSettings: blocs.$2,
                            );
                          },
                        ),
                      ],
                    ),
                    GoRoute(
                      path: 'encrypted',
                      builder: (context, state) => EncryptedVaultBackupPage(
                        wallet: state.extra! as String,
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'recover-options',
                  builder: (context, state) =>
                      RecoverOptionsScreen(wallet: state.extra! as String),
                  routes: [
                    GoRoute(
                      path: 'physical',
                      builder: (context, state) =>
                          const ImportWalletPage(isRecovery: true),
                    ),
                    GoRoute(
                      path: 'encrypted',
                      builder: (context, state) {
                        // Handle both String and bool extra parameters
                        final extra = state.extra;
                        if (extra is bool) {
                          return EncryptedVaultRecoverPage(canPop: extra);
                        }
                        return EncryptedVaultRecoverPage(
                          wallet: extra as String?,
                        );
                      },
                      routes: [
                        GoRoute(
                          path: 'info',
                          builder: (context, state) {
                            final recoveredBackup = state.extra as BullBackup?;
                            return RecoveredBackupInfoPage(
                              recoveredBackup: recoveredBackup,
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
                GoRoute(
                  path: 'keychain',
                  builder: (context, state) {
                    final (backupKey, backup, pState) =
                        state.extra! as (String?, BullBackup, String);

                    return KeychainBackupPage(
                      backupKey: backupKey,
                      backup: backup,
                      pState: pState,
                    );
                  },
                ),
                GoRoute(
                  path: 'key',
                  builder: (context, state) {
                    return BackupKeyPage(
                      wallet: state.extra! as String,
                    );
                  },
                  routes: [
                    GoRoute(
                      path: 'options',
                      builder: (context, state) {
                        final (backupKey, recoveredBackup) =
                            state.extra! as (String, BullBackup?);
                        return BackupKeyOptionsPage(
                          recoveredBackup: recoveredBackup,
                          backupKey: backupKey,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        GoRoute(
          path: '/wallet-settings/accounting',
          builder: (context, state) {
            final wallet = state.extra! as String;
            return AccountingPage(wallet: wallet);
          },
        ),
        GoRoute(
          path: '/send',
          builder: (context, state) {
            final String? deepLinkUri = state.extra as String?;
            final openscanner = deepLinkUri != null && deepLinkUri == 'scan';
            final String? walletId =
                !openscanner ? state.extra as String? : null;
            return SendPage(
              openScanner: openscanner,
              walletId: walletId,
            );
          },
        ),
        GoRoute(
          path: '/receive',
          builder: (context, state) {
            final wallet = state.extra as String?;

            return ReceivePage(wallet: wallet);
          },
        ),

        GoRoute(
          path: '/wallet',
          builder: (context, state) {
            final wallet = state.extra! as String;
            return WalletPage(wallet: wallet);
          },
        ),
        GoRoute(
          path: '/wallet/details',
          builder: (context, state) {
            final wallet = state.extra! as String;
            return WalletDetailsPage(wallet: wallet);
          },
        ),
        GoRoute(
          path: '/logs',
          builder: (context, state) {
            return const LoggerPage();
          },
        ),
        GoRoute(
          path: '/market',
          builder: (context, state) {
            return const MarketHome();
          },
        ),
        GoRoute(
          path: '/broadcast',
          builder: (context, state) {
            return const BroadcastPage();
          },
        ),

        GoRoute(
          path: '/transactions',
          builder: (context, state) {
            return const TransactionHistoryPage();
          },
        ),

        GoRoute(
          path: '/bump',
          builder: (context, state) {
            final tx = state.extra! as Transaction;
            return BumpFeesPage(tx: tx);
          },
        ),

        GoRoute(
          path: '/swap-page',
          builder: (context, state) {
            final q = state.uri.queryParameters;
            return SwapPage(fromWalletId: q['fromWalletId']);
          },
        ),

        GoRoute(
          path: '/swap-confirmation',
          builder: (context, state) {
            // TODO: Convert this to proper map
            final params = state.extra! as List;
            final sendCubit = params[0] as SendCubit;
            final swapCubit = params[1] as CreateSwapCubit;
            return SwapConfirmationPage(
              send: sendCubit,
              swap: swapCubit,
            );
          },
        ),

        GoRoute(
          path: '/swap-receive',
          builder: (context, state) {
            final tx = state.extra! as SwapTx;
            return ReceivingSwapPage(tx: tx);
          },
        ),
        GoRoute(
          path: '/onchain-swap-progress',
          builder: (context, state) {
            // TODO: Convert this to proper map
            final list = state.extra! as List;
            final swapTx = list[0] as SwapTx;
            final isReceive = list[1] as bool;
            final SendCubit? sendCubit =
                list.length == 3 ? list[2] as SendCubit : null;

            return ChainSwapProgressPage(
              swapTx: swapTx,
              isReceive: isReceive,
              sendCubit: sendCubit,
            );
          },
        ),
        GoRoute(
          path: '/swap-history',
          builder: (context, state) {
            return const SwapHistoryPage();
          },
        ),
      ],
    );

class NavName extends Cubit<String> {
  NavName() : super('');
  void update(String name) => emit(name);
}

class GoRouterObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    locator<NavName>().update(route.settings.name ?? '');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    locator<NavName>().update(previousRoute?.settings.name ?? '');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    locator<NavName>().update(newRoute?.settings.name ?? '');
  }
}

// extension GoRouterExtension on GoRouter {
//   String location() {
//     final lastMatch = routerDelegate.currentConfiguration.last;
//     final matchList = lastMatch is ImperativeRouteMatch
//         ? lastMatch.matches
//         : routerDelegate.currentConfiguration;
//     final String location = matchList.uri.toString();
//     return location;
//   }
// }
