import 'package:bb_mobile/core/locator/di_initializer.dart';
import 'package:bb_mobile/features/recover_wallet/data/datasources/bip39_word_list_data_source.dart';
import 'package:bb_mobile/features/recover_wallet/data/repositories/word_list_repository_impl.dart';
import 'package:bb_mobile/features/recover_wallet/domain/repositories/word_list_repository.dart';
import 'package:bb_mobile/features/recover_wallet/domain/usecases/find_mnemonic_words_use_case.dart';
import 'package:bb_mobile/features/recover_wallet/presentation/bloc/recover_wallet_bloc.dart';

void setupRecoverWalletDependencies() {
  // Datasources
  locator.registerLazySingleton<Bip39WordListDataSource>(
    () => Bip39EnglishWordListDataSource(),
  );
  // Repositories
  locator.registerLazySingleton<WordListRepository>(
    () => WordListRepositoryImpl(
      dataSource: locator<Bip39WordListDataSource>(),
    ),
  );

  // Use cases
  locator.registerFactory<FindMnemonicWordsUseCase>(
    () => FindMnemonicWordsUseCase(
      wordListRepository: locator<WordListRepository>(),
    ),
  );

  // Blocs
  locator.registerFactory<RecoverWalletBloc>(
    () => RecoverWalletBloc(
      findMnemonicWordsUseCase: locator<FindMnemonicWordsUseCase>(),
    ),
  );
}
