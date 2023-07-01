// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

SettingsState _$SettingsStateFromJson(Map<String, dynamic> json) {
  return _SettingsState.fromJson(json);
}

/// @nodoc
mixin _$SettingsState {
  bool get unitsInSats => throw _privateConstructorUsedError;
  bool get notifications => throw _privateConstructorUsedError;
  bool get privacyView => throw _privateConstructorUsedError; //
  Currency? get currency => throw _privateConstructorUsedError;
  List<Currency>? get currencyList => throw _privateConstructorUsedError;
  DateTime? get lastUpdatedCurrency => throw _privateConstructorUsedError;
  bool get loadingCurrency => throw _privateConstructorUsedError;
  String get errLoadingCurrency => throw _privateConstructorUsedError; //
  String? get language => throw _privateConstructorUsedError;
  List<String>? get languageList => throw _privateConstructorUsedError;
  bool get loadingLanguage => throw _privateConstructorUsedError;
  String get errLoadingLanguage => throw _privateConstructorUsedError; //
  bool get testnet => throw _privateConstructorUsedError;
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.Blockchain? get blockchain => throw _privateConstructorUsedError;
  int get reloadWalletTimer => throw _privateConstructorUsedError;
  List<ElectrumNetwork> get networks => throw _privateConstructorUsedError;
  int get selectedNetwork => throw _privateConstructorUsedError;
  bool get loadingNetworks => throw _privateConstructorUsedError;
  String get errLoadingNetworks => throw _privateConstructorUsedError; //
  int? get fees => throw _privateConstructorUsedError;
  List<int>? get feesList => throw _privateConstructorUsedError;
  int get selectedFeesOption => throw _privateConstructorUsedError; //
  bool get loadingFees => throw _privateConstructorUsedError;
  String get errLoadingFees => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $SettingsStateCopyWith<SettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SettingsStateCopyWith<$Res> {
  factory $SettingsStateCopyWith(
          SettingsState value, $Res Function(SettingsState) then) =
      _$SettingsStateCopyWithImpl<$Res, SettingsState>;
  @useResult
  $Res call(
      {bool unitsInSats,
      bool notifications,
      bool privacyView,
      Currency? currency,
      List<Currency>? currencyList,
      DateTime? lastUpdatedCurrency,
      bool loadingCurrency,
      String errLoadingCurrency,
      String? language,
      List<String>? languageList,
      bool loadingLanguage,
      String errLoadingLanguage,
      bool testnet,
      @JsonKey(includeFromJson: false, includeToJson: false)
          bdk.Blockchain? blockchain,
      int reloadWalletTimer,
      List<ElectrumNetwork> networks,
      int selectedNetwork,
      bool loadingNetworks,
      String errLoadingNetworks,
      int? fees,
      List<int>? feesList,
      int selectedFeesOption,
      bool loadingFees,
      String errLoadingFees});

  $CurrencyCopyWith<$Res>? get currency;
}

/// @nodoc
class _$SettingsStateCopyWithImpl<$Res, $Val extends SettingsState>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unitsInSats = null,
    Object? notifications = null,
    Object? privacyView = null,
    Object? currency = freezed,
    Object? currencyList = freezed,
    Object? lastUpdatedCurrency = freezed,
    Object? loadingCurrency = null,
    Object? errLoadingCurrency = null,
    Object? language = freezed,
    Object? languageList = freezed,
    Object? loadingLanguage = null,
    Object? errLoadingLanguage = null,
    Object? testnet = null,
    Object? blockchain = freezed,
    Object? reloadWalletTimer = null,
    Object? networks = null,
    Object? selectedNetwork = null,
    Object? loadingNetworks = null,
    Object? errLoadingNetworks = null,
    Object? fees = freezed,
    Object? feesList = freezed,
    Object? selectedFeesOption = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
  }) {
    return _then(_value.copyWith(
      unitsInSats: null == unitsInSats
          ? _value.unitsInSats
          : unitsInSats // ignore: cast_nullable_to_non_nullable
              as bool,
      notifications: null == notifications
          ? _value.notifications
          : notifications // ignore: cast_nullable_to_non_nullable
              as bool,
      privacyView: null == privacyView
          ? _value.privacyView
          : privacyView // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: freezed == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value.currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      lastUpdatedCurrency: freezed == lastUpdatedCurrency
          ? _value.lastUpdatedCurrency
          : lastUpdatedCurrency // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      loadingCurrency: null == loadingCurrency
          ? _value.loadingCurrency
          : loadingCurrency // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingCurrency: null == errLoadingCurrency
          ? _value.errLoadingCurrency
          : errLoadingCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languageList: freezed == languageList
          ? _value.languageList
          : languageList // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      loadingLanguage: null == loadingLanguage
          ? _value.loadingLanguage
          : loadingLanguage // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingLanguage: null == errLoadingLanguage
          ? _value.errLoadingLanguage
          : errLoadingLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as bool,
      blockchain: freezed == blockchain
          ? _value.blockchain
          : blockchain // ignore: cast_nullable_to_non_nullable
              as bdk.Blockchain?,
      reloadWalletTimer: null == reloadWalletTimer
          ? _value.reloadWalletTimer
          : reloadWalletTimer // ignore: cast_nullable_to_non_nullable
              as int,
      networks: null == networks
          ? _value.networks
          : networks // ignore: cast_nullable_to_non_nullable
              as List<ElectrumNetwork>,
      selectedNetwork: null == selectedNetwork
          ? _value.selectedNetwork
          : selectedNetwork // ignore: cast_nullable_to_non_nullable
              as int,
      loadingNetworks: null == loadingNetworks
          ? _value.loadingNetworks
          : loadingNetworks // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingNetworks: null == errLoadingNetworks
          ? _value.errLoadingNetworks
          : errLoadingNetworks // ignore: cast_nullable_to_non_nullable
              as String,
      fees: freezed == fees
          ? _value.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as int?,
      feesList: freezed == feesList
          ? _value.feesList
          : feesList // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      selectedFeesOption: null == selectedFeesOption
          ? _value.selectedFeesOption
          : selectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
              as String,
    ) as $Val);
  }

  @override
  @pragma('vm:prefer-inline')
  $CurrencyCopyWith<$Res>? get currency {
    if (_value.currency == null) {
      return null;
    }

    return $CurrencyCopyWith<$Res>(_value.currency!, (value) {
      return _then(_value.copyWith(currency: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$_SettingsStateCopyWith<$Res>
    implements $SettingsStateCopyWith<$Res> {
  factory _$$_SettingsStateCopyWith(
          _$_SettingsState value, $Res Function(_$_SettingsState) then) =
      __$$_SettingsStateCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool unitsInSats,
      bool notifications,
      bool privacyView,
      Currency? currency,
      List<Currency>? currencyList,
      DateTime? lastUpdatedCurrency,
      bool loadingCurrency,
      String errLoadingCurrency,
      String? language,
      List<String>? languageList,
      bool loadingLanguage,
      String errLoadingLanguage,
      bool testnet,
      @JsonKey(includeFromJson: false, includeToJson: false)
          bdk.Blockchain? blockchain,
      int reloadWalletTimer,
      List<ElectrumNetwork> networks,
      int selectedNetwork,
      bool loadingNetworks,
      String errLoadingNetworks,
      int? fees,
      List<int>? feesList,
      int selectedFeesOption,
      bool loadingFees,
      String errLoadingFees});

  @override
  $CurrencyCopyWith<$Res>? get currency;
}

/// @nodoc
class __$$_SettingsStateCopyWithImpl<$Res>
    extends _$SettingsStateCopyWithImpl<$Res, _$_SettingsState>
    implements _$$_SettingsStateCopyWith<$Res> {
  __$$_SettingsStateCopyWithImpl(
      _$_SettingsState _value, $Res Function(_$_SettingsState) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unitsInSats = null,
    Object? notifications = null,
    Object? privacyView = null,
    Object? currency = freezed,
    Object? currencyList = freezed,
    Object? lastUpdatedCurrency = freezed,
    Object? loadingCurrency = null,
    Object? errLoadingCurrency = null,
    Object? language = freezed,
    Object? languageList = freezed,
    Object? loadingLanguage = null,
    Object? errLoadingLanguage = null,
    Object? testnet = null,
    Object? blockchain = freezed,
    Object? reloadWalletTimer = null,
    Object? networks = null,
    Object? selectedNetwork = null,
    Object? loadingNetworks = null,
    Object? errLoadingNetworks = null,
    Object? fees = freezed,
    Object? feesList = freezed,
    Object? selectedFeesOption = null,
    Object? loadingFees = null,
    Object? errLoadingFees = null,
  }) {
    return _then(_$_SettingsState(
      unitsInSats: null == unitsInSats
          ? _value.unitsInSats
          : unitsInSats // ignore: cast_nullable_to_non_nullable
              as bool,
      notifications: null == notifications
          ? _value.notifications
          : notifications // ignore: cast_nullable_to_non_nullable
              as bool,
      privacyView: null == privacyView
          ? _value.privacyView
          : privacyView // ignore: cast_nullable_to_non_nullable
              as bool,
      currency: freezed == currency
          ? _value.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as Currency?,
      currencyList: freezed == currencyList
          ? _value._currencyList
          : currencyList // ignore: cast_nullable_to_non_nullable
              as List<Currency>?,
      lastUpdatedCurrency: freezed == lastUpdatedCurrency
          ? _value.lastUpdatedCurrency
          : lastUpdatedCurrency // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      loadingCurrency: null == loadingCurrency
          ? _value.loadingCurrency
          : loadingCurrency // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingCurrency: null == errLoadingCurrency
          ? _value.errLoadingCurrency
          : errLoadingCurrency // ignore: cast_nullable_to_non_nullable
              as String,
      language: freezed == language
          ? _value.language
          : language // ignore: cast_nullable_to_non_nullable
              as String?,
      languageList: freezed == languageList
          ? _value._languageList
          : languageList // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      loadingLanguage: null == loadingLanguage
          ? _value.loadingLanguage
          : loadingLanguage // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingLanguage: null == errLoadingLanguage
          ? _value.errLoadingLanguage
          : errLoadingLanguage // ignore: cast_nullable_to_non_nullable
              as String,
      testnet: null == testnet
          ? _value.testnet
          : testnet // ignore: cast_nullable_to_non_nullable
              as bool,
      blockchain: freezed == blockchain
          ? _value.blockchain
          : blockchain // ignore: cast_nullable_to_non_nullable
              as bdk.Blockchain?,
      reloadWalletTimer: null == reloadWalletTimer
          ? _value.reloadWalletTimer
          : reloadWalletTimer // ignore: cast_nullable_to_non_nullable
              as int,
      networks: null == networks
          ? _value._networks
          : networks // ignore: cast_nullable_to_non_nullable
              as List<ElectrumNetwork>,
      selectedNetwork: null == selectedNetwork
          ? _value.selectedNetwork
          : selectedNetwork // ignore: cast_nullable_to_non_nullable
              as int,
      loadingNetworks: null == loadingNetworks
          ? _value.loadingNetworks
          : loadingNetworks // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingNetworks: null == errLoadingNetworks
          ? _value.errLoadingNetworks
          : errLoadingNetworks // ignore: cast_nullable_to_non_nullable
              as String,
      fees: freezed == fees
          ? _value.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as int?,
      feesList: freezed == feesList
          ? _value._feesList
          : feesList // ignore: cast_nullable_to_non_nullable
              as List<int>?,
      selectedFeesOption: null == selectedFeesOption
          ? _value.selectedFeesOption
          : selectedFeesOption // ignore: cast_nullable_to_non_nullable
              as int,
      loadingFees: null == loadingFees
          ? _value.loadingFees
          : loadingFees // ignore: cast_nullable_to_non_nullable
              as bool,
      errLoadingFees: null == errLoadingFees
          ? _value.errLoadingFees
          : errLoadingFees // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_SettingsState extends _SettingsState {
  const _$_SettingsState(
      {this.unitsInSats = false,
      this.notifications = false,
      this.privacyView = false,
      this.currency,
      final List<Currency>? currencyList,
      this.lastUpdatedCurrency,
      this.loadingCurrency = false,
      this.errLoadingCurrency = '',
      this.language,
      final List<String>? languageList,
      this.loadingLanguage = false,
      this.errLoadingLanguage = '',
      this.testnet = false,
      @JsonKey(includeFromJson: false, includeToJson: false) this.blockchain,
      this.reloadWalletTimer = 20,
      final List<ElectrumNetwork> networks = const [],
      this.selectedNetwork = 1,
      this.loadingNetworks = false,
      this.errLoadingNetworks = '',
      this.fees,
      final List<int>? feesList,
      this.selectedFeesOption = 2,
      this.loadingFees = false,
      this.errLoadingFees = ''})
      : _currencyList = currencyList,
        _languageList = languageList,
        _networks = networks,
        _feesList = feesList,
        super._();

  factory _$_SettingsState.fromJson(Map<String, dynamic> json) =>
      _$$_SettingsStateFromJson(json);

  @override
  @JsonKey()
  final bool unitsInSats;
  @override
  @JsonKey()
  final bool notifications;
  @override
  @JsonKey()
  final bool privacyView;
//
  @override
  final Currency? currency;
  final List<Currency>? _currencyList;
  @override
  List<Currency>? get currencyList {
    final value = _currencyList;
    if (value == null) return null;
    if (_currencyList is EqualUnmodifiableListView) return _currencyList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final DateTime? lastUpdatedCurrency;
  @override
  @JsonKey()
  final bool loadingCurrency;
  @override
  @JsonKey()
  final String errLoadingCurrency;
//
  @override
  final String? language;
  final List<String>? _languageList;
  @override
  List<String>? get languageList {
    final value = _languageList;
    if (value == null) return null;
    if (_languageList is EqualUnmodifiableListView) return _languageList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final bool loadingLanguage;
  @override
  @JsonKey()
  final String errLoadingLanguage;
//
  @override
  @JsonKey()
  final bool testnet;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  final bdk.Blockchain? blockchain;
  @override
  @JsonKey()
  final int reloadWalletTimer;
  final List<ElectrumNetwork> _networks;
  @override
  @JsonKey()
  List<ElectrumNetwork> get networks {
    if (_networks is EqualUnmodifiableListView) return _networks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_networks);
  }

  @override
  @JsonKey()
  final int selectedNetwork;
  @override
  @JsonKey()
  final bool loadingNetworks;
  @override
  @JsonKey()
  final String errLoadingNetworks;
//
  @override
  final int? fees;
  final List<int>? _feesList;
  @override
  List<int>? get feesList {
    final value = _feesList;
    if (value == null) return null;
    if (_feesList is EqualUnmodifiableListView) return _feesList;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey()
  final int selectedFeesOption;
//
  @override
  @JsonKey()
  final bool loadingFees;
  @override
  @JsonKey()
  final String errLoadingFees;

  @override
  String toString() {
    return 'SettingsState(unitsInSats: $unitsInSats, notifications: $notifications, privacyView: $privacyView, currency: $currency, currencyList: $currencyList, lastUpdatedCurrency: $lastUpdatedCurrency, loadingCurrency: $loadingCurrency, errLoadingCurrency: $errLoadingCurrency, language: $language, languageList: $languageList, loadingLanguage: $loadingLanguage, errLoadingLanguage: $errLoadingLanguage, testnet: $testnet, blockchain: $blockchain, reloadWalletTimer: $reloadWalletTimer, networks: $networks, selectedNetwork: $selectedNetwork, loadingNetworks: $loadingNetworks, errLoadingNetworks: $errLoadingNetworks, fees: $fees, feesList: $feesList, selectedFeesOption: $selectedFeesOption, loadingFees: $loadingFees, errLoadingFees: $errLoadingFees)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_SettingsState &&
            (identical(other.unitsInSats, unitsInSats) ||
                other.unitsInSats == unitsInSats) &&
            (identical(other.notifications, notifications) ||
                other.notifications == notifications) &&
            (identical(other.privacyView, privacyView) ||
                other.privacyView == privacyView) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            const DeepCollectionEquality()
                .equals(other._currencyList, _currencyList) &&
            (identical(other.lastUpdatedCurrency, lastUpdatedCurrency) ||
                other.lastUpdatedCurrency == lastUpdatedCurrency) &&
            (identical(other.loadingCurrency, loadingCurrency) ||
                other.loadingCurrency == loadingCurrency) &&
            (identical(other.errLoadingCurrency, errLoadingCurrency) ||
                other.errLoadingCurrency == errLoadingCurrency) &&
            (identical(other.language, language) ||
                other.language == language) &&
            const DeepCollectionEquality()
                .equals(other._languageList, _languageList) &&
            (identical(other.loadingLanguage, loadingLanguage) ||
                other.loadingLanguage == loadingLanguage) &&
            (identical(other.errLoadingLanguage, errLoadingLanguage) ||
                other.errLoadingLanguage == errLoadingLanguage) &&
            (identical(other.testnet, testnet) || other.testnet == testnet) &&
            (identical(other.blockchain, blockchain) ||
                other.blockchain == blockchain) &&
            (identical(other.reloadWalletTimer, reloadWalletTimer) ||
                other.reloadWalletTimer == reloadWalletTimer) &&
            const DeepCollectionEquality().equals(other._networks, _networks) &&
            (identical(other.selectedNetwork, selectedNetwork) ||
                other.selectedNetwork == selectedNetwork) &&
            (identical(other.loadingNetworks, loadingNetworks) ||
                other.loadingNetworks == loadingNetworks) &&
            (identical(other.errLoadingNetworks, errLoadingNetworks) ||
                other.errLoadingNetworks == errLoadingNetworks) &&
            (identical(other.fees, fees) || other.fees == fees) &&
            const DeepCollectionEquality().equals(other._feesList, _feesList) &&
            (identical(other.selectedFeesOption, selectedFeesOption) ||
                other.selectedFeesOption == selectedFeesOption) &&
            (identical(other.loadingFees, loadingFees) ||
                other.loadingFees == loadingFees) &&
            (identical(other.errLoadingFees, errLoadingFees) ||
                other.errLoadingFees == errLoadingFees));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        unitsInSats,
        notifications,
        privacyView,
        currency,
        const DeepCollectionEquality().hash(_currencyList),
        lastUpdatedCurrency,
        loadingCurrency,
        errLoadingCurrency,
        language,
        const DeepCollectionEquality().hash(_languageList),
        loadingLanguage,
        errLoadingLanguage,
        testnet,
        blockchain,
        reloadWalletTimer,
        const DeepCollectionEquality().hash(_networks),
        selectedNetwork,
        loadingNetworks,
        errLoadingNetworks,
        fees,
        const DeepCollectionEquality().hash(_feesList),
        selectedFeesOption,
        loadingFees,
        errLoadingFees
      ]);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_SettingsStateCopyWith<_$_SettingsState> get copyWith =>
      __$$_SettingsStateCopyWithImpl<_$_SettingsState>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_SettingsStateToJson(
      this,
    );
  }
}

abstract class _SettingsState extends SettingsState {
  const factory _SettingsState(
      {final bool unitsInSats,
      final bool notifications,
      final bool privacyView,
      final Currency? currency,
      final List<Currency>? currencyList,
      final DateTime? lastUpdatedCurrency,
      final bool loadingCurrency,
      final String errLoadingCurrency,
      final String? language,
      final List<String>? languageList,
      final bool loadingLanguage,
      final String errLoadingLanguage,
      final bool testnet,
      @JsonKey(includeFromJson: false, includeToJson: false)
          final bdk.Blockchain? blockchain,
      final int reloadWalletTimer,
      final List<ElectrumNetwork> networks,
      final int selectedNetwork,
      final bool loadingNetworks,
      final String errLoadingNetworks,
      final int? fees,
      final List<int>? feesList,
      final int selectedFeesOption,
      final bool loadingFees,
      final String errLoadingFees}) = _$_SettingsState;
  const _SettingsState._() : super._();

  factory _SettingsState.fromJson(Map<String, dynamic> json) =
      _$_SettingsState.fromJson;

  @override
  bool get unitsInSats;
  @override
  bool get notifications;
  @override
  bool get privacyView;
  @override //
  Currency? get currency;
  @override
  List<Currency>? get currencyList;
  @override
  DateTime? get lastUpdatedCurrency;
  @override
  bool get loadingCurrency;
  @override
  String get errLoadingCurrency;
  @override //
  String? get language;
  @override
  List<String>? get languageList;
  @override
  bool get loadingLanguage;
  @override
  String get errLoadingLanguage;
  @override //
  bool get testnet;
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  bdk.Blockchain? get blockchain;
  @override
  int get reloadWalletTimer;
  @override
  List<ElectrumNetwork> get networks;
  @override
  int get selectedNetwork;
  @override
  bool get loadingNetworks;
  @override
  String get errLoadingNetworks;
  @override //
  int? get fees;
  @override
  List<int>? get feesList;
  @override
  int get selectedFeesOption;
  @override //
  bool get loadingFees;
  @override
  String get errLoadingFees;
  @override
  @JsonKey(ignore: true)
  _$$_SettingsStateCopyWith<_$_SettingsState> get copyWith =>
      throw _privateConstructorUsedError;
}
