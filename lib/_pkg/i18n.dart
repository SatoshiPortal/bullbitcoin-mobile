import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bb_mobile/settings/bloc/settings_state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_translate/flutter_translate.dart';

class Localise {
  static Future<LocalizationDelegate> getDelegate() async {
    final delegate = await LocalizationDelegate.create(
      fallbackLocale: 'en',
      supportedLocales: ['en', 'fr'],
    );

    return delegate;
  }
}

class LocaliseApp extends StatelessWidget {
  const LocaliseApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Localise.getDelegate(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return child;

        final delegate = snapshot.data!;

        return LocalizedApp(
          delegate,
          Builder(
            builder: (context) {
              return BlocListener<SettingsCubit, SettingsState>(
                listenWhen: (previous, current) =>
                    previous.language != current.language,
                listener: (context, state) {
                  if (state.language != delegate.currentLocale.languageCode)
                    delegate.changeLocale(Locale(state.language ?? 'en'));
                },
                child: LocalizationProvider(
                  state: LocalizationProvider.of(context).state,
                  child: child,
                ),
              );
            },
          ),
        );
      },
    );
  }
}
