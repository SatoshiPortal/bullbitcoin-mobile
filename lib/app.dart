                    late final AppThemeType appThemeType;
                    switch (effectiveThemeMode) {
                      case AppThemeMode.light:
                        appThemeType = AppThemeType.light;
                      case AppThemeMode.dark:
                        appThemeType = AppThemeType.dark;
                      case AppThemeMode.system:
                        appThemeType = systemBrightness == .dark
                            ? AppThemeType.dark
                            : AppThemeType.light;
                    }

                    return MultiRepositoryProvider(
                      providers: [
                        RepositoryProvider<MempoolLinks>.value(
                          value: locator<Mempool>().links,
                        ),
                        RepositoryProvider<Consolidation>(
                          create: (_) => Consolidation.open(locator<Spend>()),
                        ),
                      ],
                      child: MaterialApp.router(
                        title: 'BullBitcoin Wallet',
                        debugShowCheckedModeBanner: kDebugMode,
                        routerConfig: AppRouter.router,
                        theme: AppTheme.themeData(appThemeType),
                        locale: language?.locale,
                        localizationsDelegates: [
                          StartupLocalizations.delegate,
                          SendLocalizations.delegate,
                          NovlangReceiveLocalizationsDelegate(novlangPolicy),
                          AddressViewLocalizations.delegate,
                          NovlangLabelEditorLocalizationsDelegate(
                            novlangPolicy,
                          ),
                          NovlangAnnouncementsLocalizationsDelegate(
                            novlangPolicy,
                          ),
                          NovlangBitcoinPriceLocalizationsDelegate(
                            novlangPolicy,
                          ),
                          ...novlangLocalizationsDelegates(novlangPolicy),
                          ExchangeLocalizations.delegate,
                          LogsLocalizations.delegate,
                          NetworkLocalizations.delegate,
                          BtcMapFeature.localizationsDelegate,
                          NovlangQuickActionsLocalizationsDelegate(
                            novlangPolicy,
                            const QuickActionsFallbackDelegate(),
                          ),
                          Bip85Localizations.delegate,
                          NovlangAllSeedViewLocalizationsDelegate(
                            novlangPolicy,
                          ),
                          bullUiLocalizationsDelegate,
                          ...RecoverBullFeature.localizationsDelegates,
                        ],
                        supportedLocales: AppLocalizations.supportedLocales,
                        builder: (context, child) {
                          if (child == null) return const SizedBox.shrink();
                          // keyboard_actions still uses SDK Material widgets;
                          // the official bridge supports this transition.
                          // ignore: deprecated_member_use
                          final app = MaterialUiCompatibilityBridge(
                            child: SettingsFacade.amountScope(
                              navigatorKey: AppRouter.rootNavigatorKey,
                              child: BullSupportScope(
                                onContactSupport: SupportFacade.contactSupport,
                                child: locator<StartupFeature>().gate(
                                  logs: () => locator<LogsFacade>(),
                                  splash: const OnboardingSplash(loading: true),
                                  openOnboarding: () => AppRouter.router.go(
                                    OnboardingRoute.onboarding.path,
                                  ),
                                  onUnlocked: () =>
                                      AppLocator.startWalletsAfterUnlock(
                                        locator,
                                      ),
                                  app: locator<RecoverBullFeature>().withAlerts(
                                    child,
                                    onOpen: () => AppRouter.router.pushNamed(
                                      'recoverbullFlows',
                                    ),
