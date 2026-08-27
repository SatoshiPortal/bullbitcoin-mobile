import 'package:bb_mobile/features/btcpay/btcpay_locator.dart';
import 'package:bb_mobile/features/btcpay/data/btcpay_connection_repository_impl.dart';
import 'package:bb_mobile/features/btcpay/data/samrock_pairing_repository_impl.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/btcpay_connection_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/repositories/samrock_pairing_repository.dart';
import 'package:bb_mobile/features/btcpay/domain/samrock_pairing_request.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/complete_btcpay_samrock_pairing_usecase.dart';
import 'package:bb_mobile/features/btcpay/domain/usecases/get_btcpay_connection_usecase.dart';
import 'package:bb_mobile/features/btcpay/presentation/btcpay_pairing_cubit.dart';
import 'package:bb_mobile/features/btcpay/public/btcpay_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  test('registers only the public facade and presentation cubit', () {
    final getIt = GetIt.asNewInstance();
    addTearDown(getIt.reset);

    BtcpayLocator.setup(getIt);

    expect(getIt.isRegistered<BtcpayFacade>(), isTrue);
    expect(getIt.isRegistered<BtcpayPairingCubit>(), isTrue);
    expect(getIt.isRegistered<BtcpayConnectionRepository>(), isFalse);
    expect(getIt.isRegistered<BtcpayConnectionRepositoryImpl>(), isFalse);
    expect(getIt.isRegistered<SamRockPairingRepository>(), isFalse);
    expect(getIt.isRegistered<SamRockPairingRepositoryImpl>(), isFalse);
    expect(getIt.isRegistered<SamRockPairingRequestParser>(), isFalse);
    expect(getIt.isRegistered<GetBtcpayConnectionUsecase>(), isFalse);
    expect(getIt.isRegistered<CompleteBtcpaySamRockPairingUsecase>(), isFalse);
  });
}
