"""Keep the child mnemonic out of FRB's handler-visible argument metadata."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
before = """          esploraAddress,
          childMnemonic,
          allowUnreachableServer,
        ],
        apiImpl: this,"""
after = """          esploraAddress,
          null,
          allowUnreachableServer,
        ],
        apiImpl: this,"""
if source.count(before) + source.count(after) != 1:
    raise SystemExit("expected exactly one Scuttle open argument metadata list")
path.write_text(source.replace(before, after, 1))
