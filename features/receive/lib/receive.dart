import 'package:address_view/address_view.dart';
import 'package:bull_pricer/bull_pricer.dart';
import 'package:labels/labels.dart';
import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';

import 'src/domain/enums/receive_network_type.dart';
import 'src/domain/receive_display_preferences.dart';
import 'src/domain/receive_failure.dart';
import 'src/domain/usecases/convert_receive_amount_usecase.dart';
import 'src/domain/usecases/fetch_receive_note_suggestions_usecase.dart';
import 'src/domain/usecases/get_receive_amount_quotes_usecase.dart';
import 'src/domain/usecases/get_receive_settings_usecase.dart';
import 'src/domain/usecases/load_receive_address_label_usecase.dart';
import 'src/domain/usecases/next_unused_receive_address_usecase.dart';
import 'src/domain/usecases/save_receive_address_label_usecase.dart';

export 'src/domain/enums/receive_network_type.dart';
export 'src/domain/receive_advanced_options.dart';
export 'src/domain/receive_amount_conversion.dart';
export 'src/domain/receive_display_preferences.dart';
export 'src/domain/receive_failure.dart';
export 'src/domain/receive_lightning_limits.dart';
export 'src/domain/receive_live_amount.dart';

/// Receive request operations and address selection.
abstract interface class Receive {
  factory Receive.open({
    required AddressView addresses,
    required Labels labels,
    required Preferences preferences,
    required IndexPriceReader readPrice,
    required IndexPricesReader readPrices,
  }) = _Receive;

  /// The current receive address for a wallet selected by the transfer.
  @useResult
  Future<Result<String, ReceiveFailure>> transferAddress(String walletId);

  /// Advances until an unused address not already chosen by the caller.
  @useResult
  Future<Result<String, ReceiveFailure>> nextUnusedAddress(
    String walletId, {
    Set<String> excludedAddresses = const {},
  });

  @useResult
  Future<Result<ReceiveDisplayPreferences, ReceiveFailure>> settings({
    ReceiveNetworkType? mode,
    Network? selectedNetwork,
  });

  @useResult
  Future<Result<double, ReceiveFailure>> convertAmount({
    BigInt? amountSat,
    String? currencyCode,
  });

  @useResult
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, ReceiveFailure>>
  amountQuotes();

  @useResult
  Future<Result<String, ReceiveFailure>> loadAddressNote(String address);

  @useResult
  Future<Result<void, ReceiveFailure>> saveAddressNote({
    required String address,
    required String walletId,
    required String note,
  });

  @useResult
  Future<Result<Set<String>, ReceiveFailure>> addressNoteSuggestions();
}

final class _Receive implements Receive {
  final AddressView _addresses;
  final NextUnusedReceiveAddressUsecase _nextUnusedAddress;
  final GetReceiveSettingsUsecase _settings;
  final ConvertReceiveAmountUsecase _convert;
  final GetReceiveAmountQuotesUsecase _quotes;
  final LoadReceiveAddressLabelUsecase _loadNote;
  final SaveReceiveAddressLabelUsecase _saveNote;
  final FetchReceiveNoteSuggestionsUsecase _suggestions;

  _Receive({
    required AddressView addresses,
    required Labels labels,
    required Preferences preferences,
    required IndexPriceReader readPrice,
    required IndexPricesReader readPrices,
  }) : _addresses = addresses,
       _nextUnusedAddress = NextUnusedReceiveAddressUsecase(addresses),
       _settings = GetReceiveSettingsUsecase(preferences),
       _convert = ConvertReceiveAmountUsecase(
         getSettingsUsecase: preferences,
         getIndexPrice: readPrice,
       ),
       _quotes = GetReceiveAmountQuotesUsecase(
         settings: preferences,
         read: readPrices,
       ),
       _loadNote = LoadReceiveAddressLabelUsecase(labels),
       _saveNote = SaveReceiveAddressLabelUsecase(labels),
       _suggestions = FetchReceiveNoteSuggestionsUsecase(labels);

  @override
  Future<Result<String, ReceiveFailure>> transferAddress(
    String walletId,
  ) async =>
      (await _addresses.receiveAddress(walletId: walletId))
          .map((address) => address.address)
          .mapErr((_) => const ReceiveAddressUnavailableFailure());

  @override
  Future<Result<String, ReceiveFailure>> nextUnusedAddress(
    String walletId, {
    Set<String> excludedAddresses = const {},
  }) => _nextUnusedAddress.execute(
    walletId,
    excludedAddresses: excludedAddresses,
  );

  @override
  Future<Result<ReceiveDisplayPreferences, ReceiveFailure>> settings({
    ReceiveNetworkType? mode,
    Network? selectedNetwork,
  }) => _settings.execute(mode: mode, selectedNetwork: selectedNetwork);

  @override
  Future<Result<double, ReceiveFailure>> convertAmount({
    BigInt? amountSat,
    String? currencyCode,
  }) => _convert.execute(amountSat: amountSat, currencyCode: currencyCode);

  @override
  Future<Result<Map<SupportedCurrency, BitcoinPrice>, ReceiveFailure>>
  amountQuotes() => _quotes.execute();

  @override
  Future<Result<String, ReceiveFailure>> loadAddressNote(String address) =>
      _loadNote.execute(address);

  @override
  Future<Result<void, ReceiveFailure>> saveAddressNote({
    required String address,
    required String walletId,
    required String note,
  }) => _saveNote.execute(address: address, walletId: walletId, note: note);

  @override
  Future<Result<Set<String>, ReceiveFailure>> addressNoteSuggestions() =>
      _suggestions.execute();
}
