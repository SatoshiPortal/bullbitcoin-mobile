import 'package:bb_mobile/_pkg/storage.dart';
import 'package:bb_mobile/auth/bloc/cubit.dart';
import 'package:bb_mobile/auth/page.dart';
import 'package:bb_mobile/home/home_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:widgetbook/widgetbook.dart';

void main() {
  setupLocator();
  runApp(
    BlocProvider.value(
      value: locator<SettingsCubit>(),
      child: const BullBitcoinBook(),
    ),
  );
}

class BullBitcoinBook extends StatelessWidget {
  const BullBitcoinBook({super.key});

  @override
  Widget build(BuildContext context) {
    return Widgetbook.material(
      addons: [
        CustomThemeAddon<ThemeData>(
          setting: ThemeSetting<ThemeData>(
            themes: [
              WidgetbookTheme(
                name: 'Light',
                data: ThemeData.light(),
              ),
              WidgetbookTheme(
                name: 'Dark',
                data: ThemeData.dark(),
              ),
            ],
            activeTheme: WidgetbookTheme(
              name: 'Light',
              data: ThemeData.light(),
            ),
          ),
        ),
        TextScaleAddon(
          setting: TextScaleSetting(
            textScales: [
              1.0,
              1.5,
              2.0,
            ],
            activeTextScale: 1.0,
          ),
        ),
        FrameAddon(
          setting: FrameSetting(
            frames: [
              NoFrame(),
              DefaultDeviceFrame(
                setting: DeviceSetting(
                  devices: [
                    Apple.iPhone12Mini,
                  ],
                  activeDevice: Apple.iPhone12Mini,
                ),
              ),
              WidgetbookFrame(
                setting: DeviceSetting(
                  devices: [
                    Apple.iPhone12Mini,
                  ],
                  activeDevice: Apple.iPhone12Mini,
                ),
              ),
            ],
            activeFrame: NoFrame(),
          ),
        ),
      ],
      directories: [
        WidgetbookFolder(
          name: 'Auth',
          children: [
            WidgetbookComponent(
              name: 'Pin Area',
              useCases: [
                WidgetbookUseCase(
                  name: 'elevated',
                  builder: (context) => ElevatedButton(
                    onPressed: () {},
                    child: const Text('Widgetbook'),
                  ),
                ),
                WidgetbookUseCase(
                  name: 'elevated2',
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('zzz'),
                    ),
                  ),
                ),
              ],
            ),
            WidgetbookComponent(
              name: 'Keypad',
              useCases: [
                WidgetbookUseCase(
                  name: 'active',
                  builder: (context) {
                    final authCubit = AuthCubit(storage: locator<IStorage>());

                    return BlocProvider.value(
                      value: authCubit,
                      child: Center(
                        child: Container(
                          height: 800,
                          width: 500,
                          // color: Colors.grey,
                          child: ListView(
                            children: const [
                              AuthKeyPad(),
                              // Gap(100),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                WidgetbookUseCase(
                  name: 'disabled',
                  builder: (context) => Center(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('zzz'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        WidgetbookFolder(
          name: 'Home',
          children: [
            WidgetbookComponent(
              name: 'Page',
              useCases: [
                WidgetbookUseCase(
                  name: 'default',
                  builder: (context) => const HomePage(),
                ),
              ],
            ),
            // WidgetbookFolder(
            //   name: 'page',
            //   children: [

            //   ],
            // ),
          ],
        ),
        const WidgetbookFolder(
          name: 'Settings',
          children: [
            WidgetbookComponent(
              name: 'Page',
              useCases: [],
            ),
            WidgetbookFolder(
              name: 'Network',
              children: [],
            ),
            WidgetbookFolder(
              name: 'Fees',
              children: [],
            ),
          ],
        ),
        const WidgetbookFolder(
          name: 'New Wallet',
          children: [
            WidgetbookFolder(
              name: 'Menu',
              children: [],
            ),
            WidgetbookFolder(
              name: 'New Seed',
              children: [],
            ),
            WidgetbookFolder(
              name: 'Import',
              children: [],
            ),
            WidgetbookFolder(
              name: 'Recover',
              children: [],
            ),
            WidgetbookFolder(
              name: 'Select Wallet Type',
              children: [],
            ),
          ],
        ),
        const WidgetbookFolder(
          name: 'Wallet Settings',
          children: [
            WidgetbookFolder(
              name: 'x1',
              children: [],
            ),
          ],
        ),
        const WidgetbookFolder(
          name: 'Receive',
          children: [
            WidgetbookFolder(
              name: 'x1',
              children: [],
            ),
          ],
        ),
        const WidgetbookFolder(
          name: 'Send',
          children: [
            WidgetbookFolder(
              name: 'x1',
              children: [],
            ),
          ],
        ),
        const WidgetbookFolder(
          name: 'Transaction',
          children: [
            WidgetbookFolder(
              name: 'x1',
              children: [],
            ),
          ],
        ),
      ],
    );
  }
}
