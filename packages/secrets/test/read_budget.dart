/// Real time a sealed widget test lets pass for a keystore read to finish.
///
/// The read derives the seed through bip39 in an isolate, about 70 ms on an idle desktop and several times that on a loaded CI runner, so the budget keeps a wide margin.
const readBudgetMs = 2000;
