import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';
import 'package:bb_mobile/core/widgets/bitcoin_policy_condition.dart';
import 'package:bb_mobile/core/widgets/bitcoin_policy_description.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/settings/domain/usecases/get_wallet_policy_usecase.dart';
import 'package:bb_mobile/features/settings/domain/usecases/update_wallet_signer_device_usecase.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/wallet_details_cubit.dart';
import 'package:bb_mobile/features/settings/public/settings_facade.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_policy_details_bottom_sheet.dart';
import 'package:bb_mobile/features/settings/ui/widgets/wallet_policy_view.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_ui/bull_ui.dart' show BullBadge, BullBorderedTile;
import 'package:mocktail/mocktail.dart';

class _GetPolicy extends Mock implements GetWalletPolicyUsecase {}

class _UpdateSigner extends Mock implements UpdateWalletSignerDeviceUsecase {}

void main() {
  late _GetPolicy getPolicy;
  final wallet = Wallet(
    origin: 'recovered-vault',
    network: Network.bitcoinMainnet,
    signers: const [],
    scriptType: null,
    publicDescriptor: 'public-descriptor-fixture',
    balanceSat: BigInt.zero,
  );

  setUp(() {
    locator.pushNewScope();
    getPolicy = _GetPolicy();
    locator.registerFactory<WalletDetailsCubit>(
      () => WalletDetailsCubit(
        getWalletPolicyUsecase: getPolicy,
        updateWalletSignerDeviceUsecase: _UpdateSigner(),
      ),
    );
  });
  tearDown(() => locator.popScope());

  testWidgets('embedded and sheet viewers use the same policy contents', (
    tester,
  ) async {
    final policy = _policy();
    when(
      () => getPolicy.execute(wallet.id),
    ).thenAnswer((_) async => Ok(policy));
    await tester.pumpWidget(_app(WalletPolicyView(wallet: wallet)));
    await tester.pumpAndSettle();

    final embedded = tester.widget<WalletPolicyDetails>(
      find.byType(WalletPolicyDetails),
    );
    expect(embedded.policy, same(policy));
    expect(embedded.wallet, same(wallet));
    final policyText = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .whereType<String>()
        .toList();
    expect(policyText, contains('From the start'));
    expect(policyText, contains('AAAAAAAA + BBBBBBBB'));
    expect(policyText, contains('CCCCCCCC alone'));
    expect(policyText.any((text) => text.contains('1000000')), isTrue);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.pumpWidget(
      _app(WalletPolicyDetailsBottomSheet(wallet: wallet, policy: policy)),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<WalletPolicyDetails>(find.byType(WalletPolicyDetails))
          .policy,
      same(policy),
    );
    expect(
      tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(WalletPolicyDetails),
              matching: find.byType(Text),
            ),
          )
          .map((text) => text.data)
          .whereType<String>(),
      orderedEquals(policyText),
    );
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.text('Spending conditions'), findsOneWidget);
  });

  testWidgets('failed policy loading is explicit and can be retried', (
    tester,
  ) async {
    final pending = Completer<Result<BitcoinWalletPolicy, SettingsFailure>>();
    when(() => getPolicy.execute(wallet.id)).thenAnswer((_) => pending.future);
    await tester.pumpWidget(_app(WalletPolicyView(wallet: wallet)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(WalletPolicyDetails), findsNothing);

    pending.complete(const Err(SettingsWalletPolicyFailure()));
    await tester.pumpAndSettle();
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byType(WalletPolicyDetails), findsNothing);

    when(
      () => getPolicy.execute(wallet.id),
    ).thenAnswer((_) async => Ok(_policy()));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(WalletPolicyDetails), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    verify(() => getPolicy.execute(wallet.id)).called(2);
  });

  testWidgets('switching vaults does not keep the previous policy', (
    tester,
  ) async {
    final first = _policy();
    final second = _policy();
    when(() => getPolicy.execute(wallet.id)).thenAnswer((_) async => Ok(first));
    when(
      () => getPolicy.execute('other-vault'),
    ).thenAnswer((_) async => Ok(second));
    await tester.pumpWidget(_app(WalletPolicyView(wallet: wallet)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      _app(WalletPolicyView(wallet: wallet.copyWith(origin: 'other-vault'))),
    );
    await tester.pumpAndSettle();
    final details = tester.widget<WalletPolicyDetails>(
      find.byType(WalletPolicyDetails),
    );
    expect(details.wallet.id, 'other-vault');
    expect(details.policy, same(second));
  });

  testWidgets(
    'shared conditions show all three pairs from a two-of-three policy',
    (tester) async {
      final node = BitcoinThresholdPolicyNode(
        id: 'any-two',
        threshold: 2,
        children: [
          _signature('aaaaaaaa'),
          _signature('bbbbbbbb'),
          _signature('cccccccc'),
        ],
      );
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(wallet: wallet, policy: _policyWithRoot(node)),
        ),
      );
      for (final (first, second) in [(0, 1), (0, 2), (1, 2)]) {
        final combination = find.byKey(
          ValueKey('any-two-combination-$first-$second'),
        );
        expect(combination, findsOneWidget);
        final text = tester
            .widgetList<Text>(
              find.descendant(of: combination, matching: find.byType(Text)),
            )
            .map((t) => t.data)
            .join(' ');
        expect(text, contains(['AAAAAAAA', 'BBBBBBBB', 'CCCCCCCC'][first]));
        expect(text, contains(['AAAAAAAA', 'BBBBBBBB', 'CCCCCCCC'][second]));
      }
      expect(find.text('+'), findsNWidgets(3));
      expect(find.byType(BitcoinPolicyCondition), findsOneWidget);
      expect(find.byType(BullBorderedTile), findsOneWidget);
      expect(find.text('Spending conditions'), findsNothing);
      expect(find.text('Available spending paths'), findsNothing);
      expect(find.text('Any two keys'), findsOneWidget);
      expect(find.text('2 signatures'), findsOneWidget);
    },
  );

  testWidgets('signer badges stay inside every applicable combination', (
    tester,
  ) async {
    final node = BitcoinThresholdPolicyNode(
      id: 'any-two',
      threshold: 2,
      children: [
        _signature('aaaaaaaa'),
        _signature('bbbbbbbb'),
        _signature('cccccccc'),
      ],
    );
    for (final locked in [false, true]) {
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(
            wallet: wallet,
            policy: _policyWithRoot(node),
            signerBuilder: (context, key) => _signerLabel(
              context,
              key,
              key.value == 'aaaaaaaa'
                  ? locked
                        ? 'Locked'
                        : 'On this device'
                  : 'External',
            ),
          ),
        ),
      );
      for (final (first, second) in [(0, 1), (0, 2), (1, 2)]) {
        final combination = find.byKey(
          ValueKey('any-two-combination-$first-$second'),
        );
        final badges = tester
            .widgetList<BullBadge>(
              find.descendant(
                of: combination,
                matching: find.byType(BullBadge),
              ),
            )
            .map((badge) => badge.label)
            .toList();
        expect(badges, [
          first == 0
              ? locked
                    ? 'Locked'
                    : 'On this device'
              : 'External',
          'External',
        ]);
      }
      expect(
        find.text('On this device'),
        locked ? findsNothing : findsNWidgets(2),
      );
      expect(find.text('Locked'), locked ? findsNWidgets(2) : findsNothing);
      expect(find.text('+'), findsNWidgets(3));
      expect(find.text('Private keys in BULL'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('default condition rendering for Send and PSBT keeps the tree', (
    tester,
  ) async {
    final node = BitcoinThresholdPolicyNode(
      id: 'any-two',
      threshold: 2,
      children: [
        _signature('aaaaaaaa'),
        _signature('bbbbbbbb'),
        _signature('cccccccc'),
      ],
    );
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (context) => BitcoinPolicyCondition(
            node: node,
            describe: (node) =>
                describeBitcoinPolicyNode(context, node, wallet),
            textColor: context.appColors.onSurface,
          ),
        ),
      ),
    );
    expect(find.byType(BitcoinPolicyCondition), findsNWidgets(4));
    expect(find.text('+'), findsNothing);
  });

  testWidgets(
    'other signature thresholds do not imply that every key is required',
    (tester) async {
      final root = BitcoinThresholdPolicyNode(
        id: 'two-of-four',
        threshold: 2,
        children: [
          for (final fingerprint in [
            'aaaaaaaa',
            'bbbbbbbb',
            'cccccccc',
            'dddddddd',
          ])
            _signature(fingerprint),
        ],
      );
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(wallet: wallet, policy: _policyWithRoot(root)),
        ),
      );
      expect(find.text('Any two keys'), findsOneWidget);
      expect(find.text('2 signatures'), findsOneWidget);
      expect(find.text('+'), findsNothing);
      for (final fingerprint in [
        'AAAAAAAA',
        'BBBBBBBB',
        'CCCCCCCC',
        'DDDDDDDD',
      ]) {
        expect(find.textContaining(fingerprint), findsOneWidget);
      }
    },
  );

  for (final clockFirst in [true, false]) {
    testWidgets(
      'timeline keeps the exact timelock with clock first: $clockFirst',
      (tester) async {
        final clock = BitcoinAbsoluteTimelockPolicyNode(
          id: 'clock',
          type: BitcoinAbsoluteTimelockType.timestamp,
          value:
              DateTime.utc(2029, 4, 5, 6, 7, 8).millisecondsSinceEpoch ~/ 1000,
        );
        final signer = _signature('cccccccc');
        final path = BitcoinThresholdPolicyNode(
          id: 'delayed',
          threshold: 2,
          children: clockFirst ? [clock, signer] : [signer, clock],
        );
        await tester.pumpWidget(
          _app(
            WalletPolicyDetails(
              wallet: wallet,
              policy: _policyWithRoot(path),
              signerName: (_) => 'Inheritance Key',
            ),
          ),
        );
        expect(
          find.byKey(const ValueKey('policy-timeline-delayed')),
          findsOneWidget,
        );
        expect(find.text('Inheritance Key alone'), findsOneWidget);
        expect(find.text('1 signature'), findsOneWidget);
        expect(find.textContaining('06:07:08 UTC'), findsOneWidget);
        expect(find.textContaining('Available'), findsNothing);
        expect(find.text('From the start'), findsNothing);
        final conditions = tester.widget<BitcoinPolicyCondition>(
          find.byType(BitcoinPolicyCondition),
        );
        expect(conditions.node, same(signer));
        expect(conditions.compactSignatures, isTrue);
      },
    );
  }

  testWidgets(
    'a choice between time and a signature is not an AND timeline path',
    (tester) async {
      final clock = BitcoinAbsoluteTimelockPolicyNode(
        id: 'clock',
        type: BitcoinAbsoluteTimelockType.blockHeight,
        value: 999999,
      );
      final path = BitcoinThresholdPolicyNode(
        id: 'either',
        threshold: 1,
        children: [clock, _signature('aaaaaaaa')],
      );
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(wallet: wallet, policy: _policyWithRoot(path)),
        ),
      );
      final condition = tester.widget<BitcoinPolicyCondition>(
        find.byType(BitcoinPolicyCondition).first,
      );
      expect(condition.node, same(path));
      expect(condition.compactSignatures, isFalse);
      expect(find.textContaining('999999'), findsOneWidget);
      expect(find.text('From the start'), findsNothing);
    },
  );

  testWidgets(
    'multiple timelocks and their signature remain a complete condition tree',
    (tester) async {
      final path = BitcoinThresholdPolicyNode(
        id: 'two-clocks',
        threshold: 3,
        children: [
          BitcoinAbsoluteTimelockPolicyNode(
            id: 'absolute',
            type: BitcoinAbsoluteTimelockType.blockHeight,
            value: 999999,
          ),
          BitcoinRelativeTimelockPolicyNode(id: 'relative', value: 144),
          _signature('aaaaaaaa'),
        ],
      );
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(wallet: wallet, policy: _policyWithRoot(path)),
        ),
      );
      final condition = tester.widget<BitcoinPolicyCondition>(
        find.byType(BitcoinPolicyCondition).first,
      );
      expect(condition.node, same(path));
      expect(condition.compactSignatures, isFalse);
      expect(find.textContaining('999999'), findsOneWidget);
      expect(find.textContaining('144'), findsOneWidget);
      expect(find.text('From the start'), findsNothing);
    },
  );

  testWidgets(
    'mixed thresholds retain hashlock and relative and absolute conditions',
    (tester) async {
      final node = BitcoinThresholdPolicyNode(
        id: 'mixed',
        threshold: 2,
        children: [
          BitcoinHashlockPolicyNode(
            id: 'hash',
            type: BitcoinHashlockType.sha256,
            hash: 'public-hash-fixture',
          ),
          BitcoinRelativeTimelockPolicyNode(id: 'relative', value: 144),
          BitcoinAbsoluteTimelockPolicyNode(
            id: 'absolute',
            type: BitcoinAbsoluteTimelockType.blockHeight,
            value: 987654,
          ),
        ],
      );
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(wallet: wallet, policy: _policyWithRoot(node)),
        ),
      );
      expect(find.byType(BitcoinPolicyCondition), findsNWidgets(4));
      expect(find.text('+'), findsNothing);
      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' ');
      expect(text, contains('144'));
      expect(text, contains('987654'));
      expect(text.toLowerCase(), contains('preimage'));
    },
  );

  testWidgets(
    'local signers remain distinct without claiming private keys are loaded',
    (tester) async {
      final signers = [
        for (final fingerprint in ['aaaaaaaa', 'bbbbbbbb'])
          WalletSigner.single(
            id: fingerprint,
            masterFingerprint: fingerprint,
            xpubFingerprint: fingerprint,
            xpub: 'public-$fingerprint',
            signer: SignerEntity.local,
            signerDevice: null,
          ),
      ];
      final localWallet = wallet.copyWith(signers: signers);
      final root = BitcoinThresholdPolicyNode(
        id: 'both-local',
        threshold: 2,
        children: [_signature('aaaaaaaa'), _signature('bbbbbbbb')],
      );
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(
            wallet: localWallet,
            policy: _policyWithRoot(root),
          ),
        ),
      );
      final text = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(BitcoinPolicyCondition),
              matching: find.byType(Text),
            ),
          )
          .map((t) => t.data)
          .whereType<String>()
          .toList();
      expect(text.where((t) => t.contains('aaaaaaaa')), hasLength(1));
      expect(text.where((t) => t.contains('bbbbbbbb')), hasLength(1));
      expect(text.any((t) => t.toLowerCase().contains('loaded')), isFalse);
    },
  );

  for (final theme in [AppThemeType.light, AppThemeType.dark]) {
    testWidgets('inline signer badges fit a narrow ${theme.name} policy view', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 915);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        _app(
          WalletPolicyDetails(
            wallet: wallet,
            policy: _policy(),
            signerBuilder: (context, key) => _signerLabel(
              context,
              key,
              key.value == 'aaaaaaaa' ? 'On this device' : 'External',
            ),
          ),
          theme: theme,
        ),
      );
      expect(find.byType(BullBadge), findsNWidgets(3));
      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('External'), findsNWidgets(2));
      expect(find.text('Spending conditions'), findsNothing);
      final badge = tester.element(find.text('On this device'));
      expect(DefaultTextStyle.of(badge).style.color, badge.appColors.surface);
      expect(tester.takeException(), isNull);
    });
  }
}

Widget _signerLabel(
  BuildContext context,
  BitcoinPolicyKey key,
  String status,
) => Wrap(
  spacing: 8,
  runSpacing: 4,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: [
    Text('Cosigner ${key.value}'),
    BullBadge(
      label: status,
      background: context.appColors.primary,
      foreground: context.appColors.onPrimary,
    ),
  ],
);

Widget _app(Widget child, {AppThemeType theme = AppThemeType.light}) =>
    MaterialApp(
      theme: AppTheme.themeData(theme),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

BitcoinSignaturePolicyNode _signature(String fingerprint) =>
    BitcoinSignaturePolicyNode(
      id: fingerprint,
      key: BitcoinPolicyKey(
        kind: BitcoinPolicyKeyKind.fingerprint,
        value: fingerprint,
      ),
    );

BitcoinWalletPolicy _policyWithRoot(BitcoinPolicyNode root) {
  final spending = BitcoinSpendingPolicy(root: root, requiresPath: false);
  return BitcoinWalletPolicy(external: spending, internal: spending);
}

BitcoinWalletPolicy _policy() {
  BitcoinSignaturePolicyNode signature(String fingerprint) =>
      BitcoinSignaturePolicyNode(
        id: fingerprint,
        key: BitcoinPolicyKey(
          kind: BitcoinPolicyKeyKind.fingerprint,
          value: fingerprint,
        ),
      );
  final root = BitcoinThresholdPolicyNode(
    id: 'routes',
    threshold: 1,
    requiresPath: true,
    children: [
      BitcoinThresholdPolicyNode(
        id: 'normal',
        threshold: 2,
        children: [signature('aaaaaaaa'), signature('bbbbbbbb')],
      ),
      BitcoinThresholdPolicyNode(
        id: 'inheritance',
        threshold: 2,
        children: [
          BitcoinAbsoluteTimelockPolicyNode(
            id: 'expiry',
            type: BitcoinAbsoluteTimelockType.blockHeight,
            value: 1000000,
          ),
          signature('cccccccc'),
        ],
      ),
    ],
  );
  final spending = BitcoinSpendingPolicy(root: root, requiresPath: true);
  return BitcoinWalletPolicy(external: spending, internal: spending);
}
