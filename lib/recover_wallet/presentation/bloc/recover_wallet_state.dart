part of 'recover_wallet_bloc.dart';

enum RecoverWalletStatus { inProgress, success }

@freezed
sealed class RecoverWalletState implements _$RecoverWalletState {
  const factory RecoverWalletState({
    @Default(false) bool fromOnboarding,
    @Default(RecoverWalletStatus.inProgress) RecoverWalletStatus status,
    @Default(12) int wordsCount,
    // @Default([]) List<({String word, bool tapped})> words,
    @Default({}) Map<int, String> validWords,
    @Default({}) Map<int, List<String>> hintWords,
    @Default('') String passphrase,
    @Default(ScriptType.bip84) ScriptType scriptType,
    @Default('') String label,
    @Default(false) bool isConfirming,
    @Default(false) bool isCreating,

    // Wallet? recoveredWallet,
    @Default(null) Object? error,
  }) = _RecoverWalletState;
  const RecoverWalletState._();

  bool get hasAllValidWords => validWords.length == wordsCount && !isConfirming;
}

Map<int, String> importWords(List<String> words) =>
    Map.fromEntries(words.asMap().entries.map((e) => MapEntry(e.key, e.value)));

List<({String word, bool tapped})> importW(List<String> words) =>
    words.map((e) => (word: e, tapped: false)).toList();

List<({String word, bool tapped})> emptyWords(int len) => [
      for (int i = 0; i < len; i++) (word: '', tapped: false),
    ];

const secureTN1 = [
  'upper',
  'suffer',
  'lab',
  'cute',
  'ostrich',
  'uniform',
  'flame',
  'team',
  'swing',
  'road',
  'tilt',
  'ugly',
];

const instantTN1 = [
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
  'bacon',
];

const secureTN2 = [
  'chicken',
  'happy',
  'machine',
  'rain',
  'smile',
  'derive',
  'swamp',
  'clap',
  'trick',
  'bless',
  'balcony',
  'soon',
];

const mn1 = [
  'arrive',
  'term',
  'same',
  'weird',
  'genuine',
  'year',
  'trash',
  'autumn',
  'fancy',
  'need',
  'olive',
  'earn',
];
