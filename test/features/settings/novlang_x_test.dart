import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/public/novlang_x.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal stand-in for [SettingsCubit] that only carries state. The real
/// cubit needs a dozen use-case dependencies; the novlang helper only reads
/// `state.isSuperuser`, so a stateful [Cubit] is enough. `noSuchMethod`
/// satisfies the `implements` contract without stubbing every method.
class _FakeSettingsCubit extends Cubit<SettingsState> implements SettingsCubit {
  _FakeSettingsCubit(super.initialState);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SettingsState _stateWithSuperuser(bool? isSuperuser) {
  return SettingsState(
    storedSettings: SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      isSuperuser: isSuperuser,
    ),
  );
}

void main() {
  // Resolves `context.novlangPolicy` under a given platform + state.
  //
  // The platform override must be reset before the test body returns:
  // flutter_test asserts all foundation debug vars are unset at the end of the
  // body, which runs *before* tearDowns — so we reset in a finally here.
  Future<NewspeakPolicy> resolvePolicy(
    WidgetTester tester, {
    required SettingsState state,
    required TargetPlatform platform,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      late NewspeakPolicy policy;
      await tester.pumpWidget(
        BlocProvider<SettingsCubit>.value(
          value: _FakeSettingsCubit(state),
          child: Builder(
            builder: (context) {
              policy = context.novlangPolicy;
              return const SizedBox();
            },
          ),
        ),
      );
      return policy;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  // Renders `context.novlang(...)` and returns the chosen string.
  Future<String> resolveNovlang(
    WidgetTester tester, {
    required SettingsState state,
    required TargetPlatform platform,
    String? apple,
    String? google,
  }) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      late String rendered;
      await tester.pumpWidget(
        BlocProvider<SettingsCubit>.value(
          value: _FakeSettingsCubit(state),
          child: Builder(
            builder: (context) {
              rendered = context.novlang(
                real: 'real',
                apple: apple,
                google: google,
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return rendered;
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  group('novlangPolicy', () {
    testWidgets('iOS non-superuser → apple', (tester) async {
      expect(
        await resolvePolicy(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.iOS,
        ),
        NewspeakPolicy.apple,
      );
    });

    testWidgets('Android non-superuser → google', (tester) async {
      expect(
        await resolvePolicy(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.android,
        ),
        NewspeakPolicy.google,
      );
    });

    testWidgets('superuser → none even on iOS', (tester) async {
      expect(
        await resolvePolicy(
          tester,
          state: _stateWithSuperuser(true),
          platform: TargetPlatform.iOS,
        ),
        NewspeakPolicy.none,
      );
    });

    testWidgets('null superuser is treated as non-superuser', (tester) async {
      expect(
        await resolvePolicy(
          tester,
          state: _stateWithSuperuser(null),
          platform: TargetPlatform.iOS,
        ),
        NewspeakPolicy.apple,
      );
    });

    testWidgets('desktop platform → none', (tester) async {
      expect(
        await resolvePolicy(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.macOS,
        ),
        NewspeakPolicy.none,
      );
    });
  });

  group('novlang selector', () {
    testWidgets('apple policy uses the apple twin', (tester) async {
      expect(
        await resolveNovlang(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.iOS,
          apple: 'apple',
          google: 'google',
        ),
        'apple',
      );
    });

    testWidgets('apple policy falls back to real when no apple twin', (
      tester,
    ) async {
      expect(
        await resolveNovlang(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.iOS,
          google: 'google',
        ),
        'real',
      );
    });

    testWidgets('google policy uses the google twin', (tester) async {
      expect(
        await resolveNovlang(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.android,
          apple: 'apple',
          google: 'google',
        ),
        'google',
      );
    });

    testWidgets('google policy falls back to real when no google twin', (
      tester,
    ) async {
      expect(
        await resolveNovlang(
          tester,
          state: _stateWithSuperuser(false),
          platform: TargetPlatform.android,
          apple: 'apple',
        ),
        'real',
      );
    });

    testWidgets('none policy (superuser) always returns real', (tester) async {
      expect(
        await resolveNovlang(
          tester,
          state: _stateWithSuperuser(true),
          platform: TargetPlatform.iOS,
          apple: 'apple',
          google: 'google',
        ),
        'real',
      );
    });
  });

  group('reactivity', () {
    testWidgets('text switches when superuser toggles', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final cubit = _FakeSettingsCubit(_stateWithSuperuser(false));
      addTearDown(cubit.close);
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider<SettingsCubit>.value(
              value: cubit,
              child: Builder(
                builder: (context) => Text(
                  context.novlang(real: 'real', apple: 'apple'),
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        );

        expect(find.text('apple'), findsOneWidget);

        cubit.emit(_stateWithSuperuser(true));
        await tester.pump();

        expect(find.text('real'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
