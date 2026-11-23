# Exchange

Owns Bull Bitcoin exchange account and order values, including recurring purchases and KYC rules. `package:exchange/exchange.dart` is the consumer entry point. Transport adapters, session orchestration and credential persistence are separate follow-up slices; this slice does not change the exchange backend or storage.
