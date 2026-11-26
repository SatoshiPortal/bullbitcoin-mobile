#!/usr/bin/env bash
set -euo pipefail

destination=${1:?Pass an absolute temporary installation directory}
[[ "$destination" = /* ]] || { echo "Destination must be absolute" >&2; exit 2; }

# The peer runs outside the app, so each side keeps independent reservations.
# The private TLS feature trusts only the disposable local test certificate.
cargo install --locked \
  --git https://github.com/payjoin/rust-payjoin.git \
  --rev 7ca4b1b57964008b772de5c6139c79733ab20730 \
  --features _manual-tls --root "$destination" payjoin-cli
