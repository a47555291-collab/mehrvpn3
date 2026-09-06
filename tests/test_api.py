import importlib
import json
import os
import time
import pytest
from fastapi.testclient import TestClient
from panel.auth import hash_password
from panel.core import PERMISSIONS, transaction


@pytest.fixture
def setup(tmp_path, monkeypatch):
    monkeypatch.setenv("MEHRVPN_DB", str(tmp_path / "auth.db"))
    monkeypatch.setenv("MEHRVPN_PUBLIC_URL", "https://panel.example.test")
    import panel.app as module
    module = importlib.reload(module)
    with transaction(module.DB) as db:
        db.execute("INSERT INTO admins VALUES(?,?,?,?,?)", ("owner", hash_password("a-strong-owner-password"), json.dumps(sorted(PERMISSIONS)), 1, 1))
        db.execute("INSERT INTO admins VALUES(?,?,?,?,?)", ("viewer", hash_password("a-strong-viewer-password"), json.dumps(["dashboard", "clients.read"]), 0, 1))
    calls = []
    row = {"name":"alice", "label":"Alice", "note":"", "state":"active", "effective_state":"active", "quota_bytes":1000, "upload":10, "download":20, "expires_at":None,"created_at":1,"connections":[]}
    def fake_rpc(action, payload=None):
        calls.append((action, payload))
        if action == "list": return [row]
        if action == "config": return "client\n<key>TEST-FIXTURE-ONLY</key>\n"
        if action == "metrics": return {"history":[],"healthy":True,"online":0}
        return True
    monkeypatch.setattr(module, "rpc", fake_rpc)
    client = TestClient(module.app, base_url="https://panel.example.test")
    client.headers["origin"] = "https://panel.example.test"
    return module, client, calls


def sign_in(client, name="owner"):
    r = client.post("/api/login", json={"username": name, "password": f"a-strong-{name}-password"})
    assert r.status_code == 200, r.text
    client.headers["x-csrf-token"] = r.json()["csrf"]
    return r


def test_login_secure_cookie_and_logout(setup):
    module, c, calls = setup
    r = sign_in(c)
    cookie = r.headers['set-cookie']
    assert all(x in cookie for x in ['HttpOnly', 'Secure', 'SameSite=strict'])
    assert c.get('/api/me').json()['owner'] == 1
    assert c.post('/api/logout').status_code == 200
    assert c.get('/api/me').status_code == 401


def test_auth_csrf_and_origin_prevent_mutation(setup):
    module, c, calls = setup
    assert c.get('/api/clients').status_code == 401
    sign_in(c)
    payload={"name":"bob"}
    assert c.post('/api/clients', json=payload, headers={'x-csrf-token':'wrong'}).status_code == 403
    assert c.post('/api/clients', json=payload, headers={'origin':'https://evil.test'}).status_code == 403
    assert calls == []


def test_viewer_cannot_write_export_share_or_create_admin(setup):
    module, c, calls = setup
    sign_in(c,'viewer')
    assert c.get('/api/clients').status_code == 200
    for url in ['/api/clients/alice/config', '/api/clients/alice/qr', '/api/admins', '/api/settings']:
        assert c.get(url).status_code == 403
    assert c.post('/api/clients',json={'name':'bob'}).status_code == 403
    assert c.post('/api/share/alice').status_code == 403


def test_export_and_one_time_share(setup):
    module,c,calls=setup
    sign_in(c)
    r=c.get('/api/clients/alice/config')
    assert r.status_code==200 and 'alice.ovpn' in r.headers['content-disposition']
    assert r.headers['cache-control']=='no-store'
    share=c.post('/api/share/alice').json()
    anonymous=TestClient(module.app,base_url='https://panel.example.test')
    assert anonymous.get(share['url']).status_code==200
    assert anonymous.get(share['url']).status_code==410
    with transaction(module.DB) as db:
        events=[dict(x) for x in db.execute('SELECT * FROM audit')]
    assert 'TEST-FIXTURE' not in json.dumps(events)


def test_expired_share_fails(setup):
    module,c,calls=setup
    sign_in(c)
    url=c.post('/api/share/alice').json()['url']
    with transaction(module.DB) as db: db.execute('UPDATE shares SET expires_at=1')
    assert c.get(url).status_code==410


def test_admin_disable_invalidates_existing_sessions(setup):
    module,c,calls=setup
    viewer=TestClient(module.app,base_url='https://panel.example.test',headers={'origin':'https://panel.example.test'})
    sign_in(viewer,'viewer');sign_in(c)
    r=c.put('/api/admins/viewer',json={'username':'viewer','permissions':['dashboard'],'enabled':False})
    assert r.status_code==200,r.text
    assert viewer.get('/api/me').status_code==401


def test_owner_cannot_be_demoted_and_permissions_validated(setup):
    module,c,calls=setup
    sign_in(c)
    assert c.put('/api/admins/owner',json={'username':'owner','permissions':[],'enabled':False}).status_code==400
    assert c.put('/api/admins/other',json={'username':'other','password':'safe-long-password','permissions':['admins']}).status_code==422


def test_input_injection_and_negative_quota_rejected(setup):
    module,c,calls=setup
    sign_in(c)
    assert c.post('/api/clients',json={'name':'bob; reboot'}).status_code==422
    assert c.post('/api/clients',json={'name':'bob','quota_bytes':-1}).status_code==422
    assert c.post('/api/clients',json={'name':'bob','unexpected':'value'}).status_code==422
    assert calls==[]


def test_agent_outage_is_not_reported_as_zero_usage(setup,monkeypatch):
    module,c,calls=setup
    sign_in(c)
    def down(*args,**kwargs): raise ConnectionRefusedError()
    monkeypatch.setattr(module,'rpc',down)
    assert c.get('/api/dashboard').status_code==503
    assert c.post('/api/clients',json={'name':'bob'}).status_code==503


def test_password_change_revokes_sessions(setup):
    module,c,calls=setup
    sign_in(c)
    assert c.post('/api/password',json={'current':'a-strong-owner-password','new':'a-new-strong-password'}).status_code==200
    assert c.get('/api/me').status_code==401


def test_login_throttle(setup):
    module,c,calls=setup
    for _ in range(5):
        assert c.post('/api/login',json={'username':'owner','password':'wrong'}).status_code==401
    assert c.post('/api/login',json={'username':'owner','password':'wrong'}).status_code==429


def test_qr_overflow_is_explicit(setup,monkeypatch):
    module,c,calls=setup
    sign_in(c)
    monkeypatch.setattr(module,'rpc',lambda *args,**kwargs: 'x'*15000)
    assert c.get('/api/clients/alice/qr').status_code==413


def test_real_static_assets_and_csp(setup):
    module,c,calls=setup
    assert c.get('/').status_code==200
    assert c.get('/static/fonts/Vazir.woff2').content.startswith(b'wOF2')
    assert "frame-ancestors 'none'" in c.get('/').headers['content-security-policy']
