"""Wire a generated FRB entrypoint to its Native Assets library adapter."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
anchor = "import 'frb_generated.dart';"
import_line = "import '../native_assets_library.dart';"
if import_line not in source:
    if source.count(anchor) != 1:
        raise SystemExit(f'expected exactly one bridge import in {path}')
    source = source.replace(anchor, import_line + '\n' + anchor, 1)
before = 'externalLibrary: externalLibrary,'
after = 'externalLibrary: externalLibrary ?? nativeAssetsLibrary(),'
if source.count(before) + source.count(after) != 1:
    raise SystemExit(f'expected exactly one entrypoint library argument in {path}')
source = source.replace(before, after, 1)
path.write_text(source)
