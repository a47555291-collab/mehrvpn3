import pytest
from cryptography.exceptions import InvalidTag
from panel.backup_crypto import transform


def test_encrypted_backup_roundtrip_and_tamper_detection(tmp_path):
    source=tmp_path/'source'; encrypted=tmp_path/'backup.enc'; restored=tmp_path/'restored'
    source.write_bytes(b'private backup contents'*1000)
    transform(source,encrypted,'a-long-backup-password')
    assert b'private backup contents' not in encrypted.read_bytes()
    transform(encrypted,restored,'a-long-backup-password',True)
    assert restored.read_bytes()==source.read_bytes()
    damaged=bytearray(encrypted.read_bytes()); damaged[100]^=1; encrypted.write_bytes(damaged)
    with pytest.raises(InvalidTag):transform(encrypted,tmp_path/'tampered','a-long-backup-password',True)
    assert not (tmp_path/'tampered').exists()
    assert not (tmp_path/'tampered.partial').exists()


def test_wrong_password_never_releases_plaintext(tmp_path):
    source=tmp_path/'source'; encrypted=tmp_path/'backup.enc'
    source.write_bytes(b'secret')
    transform(source,encrypted,'correct-password')
    with pytest.raises(InvalidTag): transform(encrypted,tmp_path/'out','wrong-password',True)
    assert not (tmp_path/'out').exists()


def test_existing_partial_file_is_preserved(tmp_path):
    source=tmp_path/'source'; source.write_bytes(b'secret')
    partial=tmp_path/'out.partial'; partial.write_bytes(b'previous-work')
    with pytest.raises(FileExistsError): transform(source,tmp_path/'out','long-password')
    assert partial.read_bytes()==b'previous-work'
