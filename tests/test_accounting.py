import pytest
from panel.accounting import Accounting, parse_status, session_key
from panel.core import valid_name, client_state


@pytest.fixture
def accounts(tmp_path):
    a = Accounting(tmp_path / "state.db")
    a.add("alice", quota_bytes=1000, expires_at=5000)
    a.update("alice", state="active")
    return a


def test_periodic_and_final_counters_are_not_double_counted(accounts):
    accounts.account("alice", "session-1", 100, 200)
    accounts.account("alice", "session-1", 100, 200)
    accounts.account("alice", "session-1", 130, 250)
    accounts.account("alice", "session-1", 120, 240)  # delayed older status
    row = accounts.list()[0]
    assert (row["upload"], row["download"]) == (130, 250)


def test_reconnect_and_persistence(accounts):
    accounts.account("alice", "session-1", 100, 200)
    a = Accounting(accounts.path)
    a.account("alice", "session-2", 10, 20)
    assert a.list()[0]["upload"] == 110
    assert a.list()[0]["download"] == 220


def test_reset_preserves_active_session_baselines(accounts):
    accounts.account("alice", "session-1", 100, 200)
    accounts.reset("alice")
    accounts.account("alice", "session-1", 110, 250)
    assert (accounts.list()[0]["upload"], accounts.list()[0]["download"]) == (10, 50)


def test_policy_boundaries_and_permanent_revocation(accounts):
    row = accounts.list()[0]
    assert client_state(row, 4999) == "active"
    assert client_state(row, 5000) == "expired"
    row.update(expires_at=None, upload=499, download=501)
    assert client_state(row, 1) == "quota"
    row.update(quota_bytes=0)
    assert client_state(row, 1) == "active"
    row.update(state="revoked")
    assert client_state(row, 1) == "revoked"


def test_session_owner_mismatch_rejected(accounts):
    accounts.account("alice", "s", 100, 200)
    with pytest.raises(ValueError):
        accounts.account("bob", "s", 100, 200)


def test_negative_counts_rejected(accounts):
    with pytest.raises(ValueError):
        accounts.account("alice", "s", -1, 0)


@pytest.mark.parametrize("name", ["../root", "server", "ca", "x;reboot", "x\nkill all", "--option", "", "الف", "a"*49])
def test_unsafe_identifiers_rejected(name):
    with pytest.raises(ValueError):
        valid_name(name)


def test_status_headers_not_fixed_column_offsets():
    source = 'TITLE\tOpenVPN 2.6\nHEADER\tCLIENT_LIST\tCommon Name\tReal Address\tVirtual Address\tBytes Received\tBytes Sent\tConnected Since (time_t)\tPeer ID\nCLIENT_LIST\talice\t1.2.3.4:4321\t10.8.0.2\t123\t456\t1700000000\t1\nEND\n'
    rows = parse_status(source)
    assert rows == [{"name": "alice", "remote": "1.2.3.4:4321", "vpn_ip": "10.8.0.2", "upload": 123, "download": 456, "since": 1700000000}]
    assert session_key("alice", "1.2.3.4:4321", 1700000000) == "alice|1.2.3.4:4321|1700000000"
    with pytest.raises(ValueError):
        parse_status(source.replace("END\n", ""))
