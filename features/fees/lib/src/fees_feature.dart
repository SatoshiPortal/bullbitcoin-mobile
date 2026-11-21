import 'package:fees/fees.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'domain/usecases/load_fee_source_usecase.dart';
import 'domain/usecases/save_fee_source_usecase.dart';
import 'fees_l10n.dart';
import 'presentation/fee_source_cubit.dart';
import 'ui/fee_source_screen.dart';

const _feeSourceRoute = 'bitcoinFeeSource';

final class FeesFeature {
  final List<GoRoute> routes;

  const FeesFeature._(this.routes);

  factory FeesFeature.mount({required Fees Function() fees}) => FeesFeature._(
    List.unmodifiable([
      GoRoute(
        path: '/bitcoin-fee-source',
        name: _feeSourceRoute,
        builder: (_, _) => BlocProvider(
          create: (_) {
            final capability = fees();
            return FeeSourceCubit(
              loadSource: LoadFeeSourceUsecase(capability),
              saveSource: SaveFeeSourceUsecase(capability),
            )..load();
          },
          child: const FeeSourceScreen(),
        ),
      ),
    ]),
  );
}

abstract final class FeesNavigation {
  static String settingsTitle(String localeName) =>
      feesCopy(localeName).settingsTitle;

  static Future<void> openSettings(BuildContext context) =>
      context.pushNamed<void>(_feeSourceRoute);
}
