import hashlib
import json
from pathlib import Path
from panel.core import valid_name


def test_vendored_upstream_is_byte_for_byte_pinned():
    vendor=Path(__file__).parent.parent/'vendor'
    source=json.loads((vendor/'source.json').read_text())
    assert source['commit']=='d5e860573c135648f0148f6060cb9b6ec1fb47f3'
    assert hashlib.sha256((vendor/'openvpn-install.sh').read_bytes()).hexdigest()==source['sha256']


def test_legacy_numeric_and_underscore_names_can_be_imported():
    assert valid_name('123_client')=='123_client'
    assert valid_name('_client')=='_client'
