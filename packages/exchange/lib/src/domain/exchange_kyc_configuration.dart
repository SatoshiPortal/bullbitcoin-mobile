/// Environment-scoped configuration for opening the verification web view.
typedef ExchangeKycConfiguration = ({
  Uri url,
  ({String username, String password})? basicAuth,
});
