sealed class LnurlPayLimitsApplicationException implements Exception {
  const LnurlPayLimitsApplicationException();
}

class LnurlPayLimitsInvalidApplicationException
    extends LnurlPayLimitsApplicationException {
  const LnurlPayLimitsInvalidApplicationException();
}

class LnurlPayLimitsUnavailableApplicationException
    extends LnurlPayLimitsApplicationException {
  const LnurlPayLimitsUnavailableApplicationException();
}
