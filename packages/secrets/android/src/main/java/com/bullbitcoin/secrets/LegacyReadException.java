package com.bullbitcoin.secrets;

/** Fixed codes only: exceptions from parsers and providers may contain stored data. */
final class LegacyReadException extends Exception {
    final String code;

    LegacyReadException(String code) {
        super(code);
        this.code = code;
    }
}
