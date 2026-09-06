import time
import pytest
from panel.agent import Agent


@pytest.fixture
def agent(tmp_path):
    vpn=tmp_path/'vpn'
    (vpn/'easy-rsa/pki').mkdir(parents=True)
    return Agent(str(tmp_path/'state'),str(vpn))


def test_hook_fails_closed_when_monitor_stale(agent):
    agent.accounts.add('alice')
    agent.accounts.update('alice',state='active')
    assert agent.dispatch('check',{'name':'alice'},hook=True) is False
    agent.last_ok=time.time()
    assert agent.dispatch('check',{'name':'alice'},hook=True) is True
    agent.accounts.update('alice',state='suspended')
    assert agent.dispatch('check',{'name':'alice'},hook=True) is False


def test_hook_socket_cannot_perform_admin_operations(agent):
    for action in ['create','revoke','config','restart','update']:
        with pytest.raises(ValueError): agent.dispatch(action,{'name':'alice'},hook=True)


def test_final_hook_updates_usage_and_blocks_reconnect(agent):
    agent.accounts.add('alice',quota_bytes=100)
    agent.accounts.update('alice',state='active')
    agent.last_ok=time.time()
    payload={'name':'alice','remote':'1.2.3.4:5678','since':100,'upload':60,'download':50}
    agent.dispatch('disconnect',payload,hook=True)
    agent.dispatch('disconnect',payload,hook=True)
    assert agent.accounts.list()[0]['upload']==60
    assert agent.dispatch('check',{'name':'alice'},hook=True) is False


def test_profile_uses_upstream_template_and_inline_without_cipher_changes(agent):
    agent.accounts.add('alice');agent.accounts.update('alice',state='active')
    p=agent.vpn/'easy-rsa/pki/inline/private';p.mkdir(parents=True)
    (agent.vpn/'client-common.txt').write_text('client\nproto udp\nremote 203.0.113.1 1194\nauth SHA512\n')
    (p/'alice.inline').write_text('# comment\n<ca>\nCA\n</ca>\n<cert>\nCERT\n</cert>\n<key>\nKEY\n</key>\n<tls-crypt>\nTLS\n</tls-crypt>\n')
    profile=agent.config('alice')
    assert 'proto udp\nremote 203.0.113.1 1194\nauth SHA512' in profile
    assert '# comment' not in profile and 'cipher ' not in profile
    agent.accounts.update('alice',state='revoked')
    with pytest.raises(ValueError): agent.config('alice')
