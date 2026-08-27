import 'package:bb_mobile/features/bullnym/data/bullnym_http_datasource.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_repository_impl.dart';
import 'package:bb_mobile/features/bullnym/data/bullnym_response_decoder.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_config.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/nostr_identity/public/nostr_identity_facade.dart';
import 'package:get_it/get_it.dart';

final class BullnymLocator {
  static void setup(GetIt locator) {
    locator.registerFactory<BullnymFacade>(() {
      final repository = BullnymRepositoryImpl(
        BullnymHttpDatasource(),
        BullnymResponseDecoder(
          validateBullnymPublicOrigin(bullnymDefaultPublicBaseUrl),
        ),
      );
      final authenticator = BullnymAuthenticator(
        locator<NostrIdentityFacade>(),
      );
      return BullnymFacade.create(repository, authenticator);
    });
  }
}
