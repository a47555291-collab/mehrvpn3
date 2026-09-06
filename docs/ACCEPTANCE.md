# Linux server acceptance test — not yet executed

Use a disposable VPS and a separate client device before accepting a deployment. Record OS/OpenVPN versions, commit, date, observed outcomes and logs without private keys. These checks require a real server and are not replaced by the unit/API tests.

1. **Installation**: run `install.sh` on clean Ubuntu/Debian. Verify all three services are active, nginx configuration is valid, panel HTTPS loads, and only intended ports are exposed. Verify hook execution under the installed OpenVPN systemd/AppArmor policy; investigate denials rather than disabling host security globally.
2. **Standard connection**: create `test_normal`, download the `.ovpn`, import into an official OpenVPN client on a separate network, and connect. Verify the TLS handshake, assigned tunnel address, DNS resolution, access to a website and observed public egress IP. Test ICMP to a known reachable endpoint if permitted; ICMP filtering alone does not prove tunnel failure.
3. **Real usage**: transfer a file through the VPN, compare per-client counters with OpenVPN's status and confirm they increase. Disconnect/reconnect and verify totals are not reset or counted twice. Repeat a connection shorter than the polling interval and confirm final hook accounting.
4. **Volume**: set a small quota above current usage, transfer past it, confirm the session is disconnected and reconnect is denied. Measure overshoot. Increase the quota or reset usage and confirm reconnect succeeds with the same profile.
5. **Time**: set expiry a few minutes ahead, keep the connection active, confirm disconnect after the enforcement interval and deny reconnect. Extend expiry and verify the same profile works.
6. **Administrative actions**: suspend/resume, disconnect, reset and revoke. Revocation must remain denied after reboot. Old downloaded files must not regain access.
7. **Persistence**: reboot the server with existing usage, confirm durable totals and service startup. Abrupt power loss may lose unsampled final bytes; document this limitation.
8. **Failure policy**: stop the agent and confirm systemd stops OpenVPN. Make management unavailable while leaving the process alive and confirm the monitor stops OpenVPN after the timeout. Restore services and verify accounting before reconnecting.
9. **Permissions**: create a view-only administrator. Verify direct API calls cannot create/revoke/export clients or edit settings. Disable the account and confirm existing sessions cease working. Ensure owner cannot be disabled from the web UI.
10. **QR/download**: test normal file import, profile copy, oversized-profile feedback and a temporary QR on a second device. Confirm one successful download consumes the token; confirm expiration after 5 minutes. Never place private profiles in screenshots or public logs.
11. **Backup recovery**: back up, decrypt with the password, restore on a separate test server, and validate database/PKI consistency. Confirm tampered backups and incorrect passwords are rejected. Adjust endpoint settings for a new server IP.
12. **Existing installation**: repeat on an existing installation made by the pinned upstream script. Compare issued profile protocol/cipher/TLS contents before/after integration. Verify imported users remain connectable.
13. **Browser usability**: test all pages in Persian RTL and English LTR, dark/light mode, mobile widths, keyboard navigation, dialogs, copy/download, search/filter/pagination, administrator permissions and meaningful server-outage feedback.

Acceptance evidence must distinguish application tests from actual server/network results. Do not describe a profile as working or ping-tested without step 2 passing on a real server.
