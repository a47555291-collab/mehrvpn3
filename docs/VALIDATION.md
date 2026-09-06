# Validation record — 2026-09-06

## Passed in the development environment

- 38 Python tests: persisted usage accounting, replayed/stale counters, reconnects, reset baselines, quota/expiry boundaries, hook rejection when monitoring is stale, final disconnect accounting, original profile assembly, unsafe identifiers, authentication, CSRF, origin checks, RBAC, disabled-admin session invalidation, permanent-owner protection, private-profile export, one-time/expired download links, QR overflow, password changes, login throttling, encrypted-backup roundtrip/tamper/wrong-password checks, preservation of existing temporary files, legacy client names and upstream integrity.
- 4 DOM interaction tests: bilingual navigation and correct quota/expiry payloads, restricted controls for view-only roles, honest server-outage feedback, search/admin/settings/logout interactions. These use test-only fixtures, not live VPN connections or a browser rendering engine.
- JavaScript syntax check passed.
- ShellCheck v0.11.0 warning-level analysis passed for the installer, OpenVPN hook wrapper, backup and upgrade scripts.
- Dependency audit of the constrained runtime requirements: no known vulnerabilities reported by pip-audit on this date.
- Live local HTTP smoke checks: login 200, settings 200, dashboard/profile 503 without the Linux agent. The missing agent is not replaced by fabricated data.
- The vendored installer hash matches its pinned upstream revision byte for byte.
- Locally bundled Vazir variable WOFF2 font and its OFL license are present.

The Python tests report deprecation warnings in test-client dependencies (httpx integration / AnyIO aliases). They do not fail and do not affect the runtime web server.

## Not yet verified

- Fresh or existing-VPS installation under actual Ubuntu/Debian systemd and AppArmor policies.
- Real OpenVPN TLS handshake, client import, routed internet access, DNS behavior, public egress IP and ping from an external client.
- Quota/expiry overshoot under real bandwidth and load, watchdog behavior on a running VPN, abrupt-host-failure behavior.
- Real nginx/certificate/cloud-firewall configuration, upgrade and backup restoration on Linux.
- Pixel-level browser rendering, accessibility with assistive technology and mobile-device testing. DOM tests do not establish visual layout quality.

Run `ACCEPTANCE.md` on a disposable VPS before production. This release is ready for server acceptance testing; it is not labeled production-verified or ping-tested.

## فارسی

۳۸ آزمون پشت‌صحنه و ۴ آزمون تعامل رابط موفق بوده‌اند. بررسی نگارشی JavaScript، بررسی اسکریپت‌های نصب و audit وابستگی‌های اجرا نیز انجام شده است. اصل اسکریپت OpenVPN تغییر نکرده است.

هنوز نصب واقعی روی VPS، اتصال کلاینت خارجی، پینگ، عملکرد شبکه و ظاهر در مرورگر واقعی آزمایش نشده‌اند. بنابراین نسخه برای **آزمایش روی سرور** آماده است و ادعای تأیید عملیاتی یا پینگ موفق ندارد.
