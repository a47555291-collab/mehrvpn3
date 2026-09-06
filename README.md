# MehrVPN / مهر وی‌پی‌ان

پنل وب فارسی و انگلیسی برای مدیریت **OpenVPN**، با فونت وزیر، آمار واقعی سرور، سهمیهٔ مصرف، انقضا و دسترسی مدیران.

**وضعیت: نسخهٔ اولیه برای آزمایش روی سرور.** آزمون‌های خودکار منطق برنامه و API اجرا شده‌اند؛ نصب واقعی لینوکس، تونل و پینگ از دستگاه بیرونی هنوز در محیط این پروژه آزمایش نشده‌اند. پیش از استفادهٔ عمومی، مراحل `docs/ACCEPTANCE.md` را اجرا کنید.

## قابلیت‌ها

- داشبورد با CPU، RAM، دیسک، uptime، نمودار نرخ انتقال شبکه و شمار اتصال‌های OpenVPN.
- نگهداری ۲۴ ساعت دادهٔ نمودار روی سرور؛ نمونه‌برداری منابع هر ۳۰ ثانیه.
- ساخت تکی یا گروهی کلاینت، جستجو، فیلتر و خروجی CSV.
- دانلود فایل استاندارد `.ovpn` و کپی محتوای آن.
- QR مستقیم در صورت جا شدن کانفیگ؛ QR لینک دانلود یک‌بارمصرف با اعتبار ۵ دقیقه برای فایل‌های بزرگ.
- سهمیه بر اساس مجموع upload + download، انقضا، تمدید، تعلیق، فعال‌سازی، قطع نشست و ابطال دائمی گواهی.
- مجوزهای مستقل مشاهده، ساخت/ویرایش، دریافت کانفیگ، تنظیمات و گزارش عملیات؛ فقط مالک مدیر اضافه می‌کند.
- ورود با رمز هش‌شدهٔ Argon2، نشست ۸ساعته، محدودسازی تلاش ورود، محافظت CSRF و ثبت عملیات.
- رابط واکنش‌گرا، فارسی/انگلیسی، RTL/LTR، روشن/تاریک و فونت وزیر محلی؛ بدون وابستگی ظاهری به CDN.
- تنظیم نام پنل و پیش‌فرض حجم/مدت؛ نمایش تنظیمات پروتکل، تغییر رمز و راه‌اندازی مجدد OpenVPN.
- پشتیبان رمز‌شده و قابل بررسی از نظر دست‌کاری، از طریق ابزار سرور.

## حفظ پروژهٔ اصلی

نسخهٔ دست‌نخوردهٔ مخزن زیر در `vendor/` قرار دارد:

- مخزن: https://github.com/aminiyt1/openvpn-install
- commit: `d5e860573c135648f0148f6060cb9b6ec1fb47f3`
- SHA-256: `f97c0c24ffbb3d37f72b6f327ed893c149113e290d76a64b13bc99b8e25f063f`

نصاب در سرور تازه همان اسکریپت را اجرا می‌کند. پنل برای کلاینت‌های بعدی همان دستور EasyRSA (`build-client-full … nopass` با اعتبار ۳۶۵۰ روز) و همان ترکیب `client-common.txt` با پروفایل inline را به کار می‌برد. فرمت کانفیگ، پروتکل، پورت، cipher و TLS اصلی تغییر داده نمی‌شوند. در تنظیمات سرور فقط سوکت مدیریت محلی و hookهای کنترل دسترسی/مصرف اضافه می‌شوند.

اعتبار اشتراک در پایگاه داده مستقل از عمر گواهی است. انقضا و اتمام حجم، دسترسی را مسدود می‌کنند؛ تمدید به صدور مجدد گواهی نیاز ندارد. ابطال دائمی گواهی برگشت‌پذیر نیست.

## نصب

هدف نصاب: **Ubuntu 22.04/24.04 و Debian 12/13** با systemd، IPv4 و TUN فعال. سازگاری سایر توزیع‌ها در این نسخه ادعا نمی‌شود؛ پشتیبانی بیشتر اسکریپت اصلی به معنی پشتیبانی همین پنل نیست.

بسته را روی VPS استخراج کنید، وارد پوشه شوید و اجرا کنید:

```bash
sudo bash install.sh
```

نصاب آدرس عمومی سرور، پورت HTTPS پنل (پیش‌فرض `8443`)، نام مدیر و رمز را می‌پرسد. در سرور تازه، منوی اصلی پروژه برای پورت، UDP/TCP، DNS و کلاینت اول باز می‌شود. پس از آن پنل، سرویس‌ها و HTTPS تنظیم می‌شوند.

نسخهٔ اولیهٔ گیت‌هاب و دستور دانلود یک‌خطی هنوز منتشر نشده‌اند؛ URL فرضی برای نصب ساخته نشده است.

**HTTPS:** برای IP یا دامنه، گواهی خودامضا تولید می‌شود. اثر انگشت SHA-256 در پایان نصب چاپ می‌شود؛ پیش از اعتماد مرورگر با آن مقایسه کنید. برای استفادهٔ عمومی، گواهی معتبر دامنه را جایگزین `/etc/mehrvpn/tls/panel.crt` و `panel.key` کنید و `nginx` را reload کنید. نگهداری و تمدید خودکار گواهی دامنه در این نسخه پیکربندی نشده است.

پورت TCP پنل و پورت/پروتکل VPN را در فایروال ارائه‌دهندهٔ VPS نیز باز کنید. نصاب قانون پنل را در UFW یا firewalld فعال اضافه می‌کند؛ به فایروال ابری شما دسترسی ندارد. استفاده از پورت از پیش اشغال‌شده رد می‌شود.

### سرور دارای OpenVPN

ساختار باید با مخزن مبنا سازگار باشد. کلاینت‌های معتبر موجود وارد پنل می‌شوند؛ مصرف تاریخی آن‌ها قابل بازیابی نیست و از نصب پنل حساب می‌شود. استفادهٔ هم‌زمان از منوی اصلی برای تغییر کاربران بعد از نصب پنل توصیه نمی‌شود، چون پایگاه دادهٔ پنل دور زده می‌شود.

نصاب نصب‌های دارای management، hook احراز هویت، plugin یا `duplicate-cn` را خودکار تغییر نمی‌دهد. ادغام آن‌ها نیازمند بررسی دستی است. این نسخه یک نمونهٔ OpenVPN روی هر سرور را مدیریت می‌کند و WireGuard ندارد.

## حجم و زمان چگونه اعمال می‌شوند؟

1. وضعیت اتصال‌ها و بایت‌های OpenVPN از سوکت Unix محلی هر حدود ۲ ثانیه خوانده می‌شود.
2. اختلاف شمارنده‌ها برای هر نشست در SQLite ذخیره می‌شود؛ تکرار نمونه یا دریافت نمونهٔ قدیمی دوباره مصرف اضافه نمی‌کند.
3. hook قطع اتصال، شمارندهٔ نهایی را هم ثبت می‌کند؛ اتصال‌های کوتاه بین دو نمونه نیز حساب می‌شوند.
4. با اتمام حجم، انقضا یا تعلیق، نشست فعال از رابط مدیریت قطع می‌شود.
5. hook اتصال اجازهٔ ورود دوبارهٔ کاربر مسدودشده یا ناشناخته را نمی‌دهد.
6. ازکارافتادن فرایند عامل، از طریق `BindsTo` سرویس VPN را متوقف می‌کند. خرابی پایش بیش از ۱۵ ثانیه نیز باعث توقف VPN می‌شود. پس از رفع مشکل از پنل یا systemd آن را راه‌اندازی کنید.

این روش **سهمیهٔ حساب‌شده و اجرایی** است، نه نمایش یک عدد در رابط. اما packet-by-packet نیست: در فاصلهٔ دو بررسی و هنگام تأخیر کنترل، عبور از سقف ممکن است؛ مقدار آن به سرعت و بار سرور بستگی دارد. بعد از قطع برق یا kill ناگهانی خود OpenVPN، بایت‌های بعد از آخرین نمونه ممکن است ثبت نشده باشند. پس از restart معمولی مصرف ذخیره‌شده حفظ می‌شود. `Reset usage` شمارندهٔ مصرف را صفر می‌کند و baseline نشست‌های فعال را حفظ می‌کند.

واحد ورودی حجم **GiB = 1024³ بایت** است. مجموع بایت‌های تونل با قبض ترافیک VPS یکسان نیست، چون سربار پروتکل و سایر ترافیک سرور جدا هستند. نمودار داشبورد نرخ تمام رابط‌های شبکه است و ممکن است ترافیک تونل و رابط فیزیکی را هر دو شامل شود؛ برای صورتحساب کاربران از شمارندهٔ هر کلاینت استفاده کنید.

## معماری و امنیت

```text
Browser → HTTPS nginx → FastAPI (user: mehrvpn)
                          ↓ local Unix socket, allowlisted operations
                     Agent (root) → EasyRSA / OpenVPN management
                          ↑ local hook socket
                     OpenVPN connect/disconnect hooks
```

- وب روی `127.0.0.1:8097` گوش می‌کند و root نیست.
- عامل root، شنوندهٔ شبکه ندارد و shell دلخواه اجرا نمی‌کند.
- سوکت مدیریت OpenVPN فقط peer با هویت root را می‌پذیرد.
- سوکت hook فقط عملیات بررسی دسترسی و ثبت شمارندهٔ نهایی دارد.
- کلیدهای خصوصی و پایگاه PKI در اختیار root می‌مانند. export مجاز، محتوا را در پاسخ بدون cache ارسال می‌کند.
- دانلود با لینک موقت نیازمند ورود دریافت‌کننده نیست؛ دارندهٔ لینک تا اولین دریافت یا پایان ۵ دقیقه به فایل خصوصی دسترسی دارد. token به شکل هش ذخیره می‌شود.
- access log پراکسی و uvicorn برای جلوگیری از ثبت token لینک‌ها خاموش است. گزارش مدیریتی در خود پنل ذخیره می‌شود.
- دسترسی مدیران در این نسخه سراسری است؛ تفکیک کاربران بر اساس نمایندگی/مالکیت وجود ندارد.
- نقش دارای `clients.write` می‌تواند همهٔ کلاینت‌ها را مدیریت کند؛ نقش `clients.export` می‌تواند کلید خصوصی پروفایل را دریافت کند. این مجوز را محدود بدهید.
- تغییر نام دامنه باید هم‌زمان در nginx، گواهی و `MEHRVPN_PUBLIC_URL` فایل `/etc/mehrvpn/panel.env` انجام شود؛ سپس وب restart شود.

## مدیریت سرور

```bash
systemctl status mehrvpn-agent mehrvpn-web openvpn-server@server
journalctl -u mehrvpn-agent -u mehrvpn-web -u openvpn-server@server --since '10 minutes ago'

# بازیابی رمز مالک از کنسول سرور
cd /opt/mehrvpn
sudo .venv/bin/python -m panel.cli reset-password --username admin

# پشتیبان رمز‌شده؛ اتصال‌ها برای سازگاری پایگاه داده موقتاً قطع می‌شوند
sudo bash /opt/mehrvpn/scripts/backup.sh
```

### بازیابی پشتیبان

این کار تنظیمات سرور را جایگزین می‌کند؛ ابتدا روی سرور آزمایشی انجام دهید. نسخهٔ سازگار MehrVPN و OpenVPN باید نصب باشد. فایل `.enc` دارای کلید CA، کلیدهای کاربران و دادهٔ مدیران است؛ آن را محرمانه نگه دارید.

```bash
cd /opt/mehrvpn
sudo .venv/bin/python -m panel.backup_crypto decrypt /path/to/backup.tar.gz.enc /root/mehrvpn-restore.tar.gz
# رمز و صحت محتوا قبل از انتشار فایل خروجی بررسی می‌شود.
sudo tar -tzf /root/mehrvpn-restore.tar.gz
# پس از بررسی فهرست فایل‌ها و اطمینان از سرور مقصد:
sudo systemctl stop mehrvpn-web openvpn-server@server mehrvpn-agent
sudo tar -xzf /root/mehrvpn-restore.tar.gz -C /
sudo systemctl daemon-reload
sudo systemctl start mehrvpn-agent
# صبر کنید تا /run/mehrvpn/control.sock ایجاد شود.
sudo systemctl start openvpn-server@server mehrvpn-web
sudo nginx -t && sudo systemctl reload nginx
```

فایل plaintext بازیابی را پس از اتمام از محل امن خود پاک کنید. پشتیبان به‌صورت AES-256-GCM و PBKDF2 رمز می‌شود؛ بدون رمز قابل بازیابی نیست. مسیر آدرس سرور، گواهی HTTPS و `local` در صورت مهاجرت به IP جدید نیاز به تنظیم دارند.

### بروزرسانی

از پوشهٔ نسخهٔ جدید اجرا کنید:

```bash
sudo bash scripts/upgrade.sh
```

ابتدا پشتیبان رمز‌شده تهیه می‌شود. PKI، تنظیمات OpenVPN و داده‌ها بازنشانی نمی‌شوند. ارتقا اتصال‌ها را قطع می‌کند. در شکست نصب وابستگی یا مهاجرت، سرویس متوقف می‌ماند تا نسخه/پشتیبان بررسی شود؛ rollback خودکار نسخهٔ برنامه وجود ندارد.

## توسعه و آزمون

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements-dev.txt
.venv/bin/python -m pytest -q
node --check panel/static/app.js
shellcheck -S warning install.sh scripts/*.sh

# آزمون‌های تعامل رابط بدون مرورگر؛ فقط در محیط توسعه به Node نیاز دارد
npm ci
npm test
```

وابستگی‌های اجرا در `requirements.txt` و `constraints.txt` ثابت شده‌اند. هنگام بروزرسانی هر دو را بازبینی و audit کنید. ابزارهای آزمون و fixtureها به محیط عملیاتی دادهٔ ساختگی اضافه نمی‌کنند.

برای اجرای وب بدون عامل فقط روی دستگاه توسعه:

```bash
export MEHRVPN_DB="$PWD/dev/panel.db"
export MEHRVPN_PUBLIC_URL=http://127.0.0.1:8097
.venv/bin/python -m panel.cli owner
.venv/bin/python -m uvicorn panel.app:app --host 127.0.0.1 --port 8097
```

در نبود عامل لینوکسی، صفحهٔ ورود و رابط کار می‌کنند ولی داشبورد/کلاینت‌ها خطای اتصال نشان می‌دهند؛ کانفیگ یا آمار جعلی ساخته نمی‌شود. HTTP عمومی در تنظیمات برنامه رد می‌شود.

## مجوز و منابع

- کد پنل: MIT، فایل `LICENSE`.
- اسکریپت اصلی و مجوز آن: `vendor/LICENSE.txt`؛ اعلان حق مؤلف اصلی حفظ شده است.
- فونت Vazir v30.1.0: `panel/static/fonts/OFL.txt`، [مخزن فونت](https://github.com/rastikerdar/vazir-font).
- [رابط مدیریت OpenVPN](https://openvpn.net/community-docs/management-interface.html)
- [مرجع OpenVPN 2.6](https://openvpn.net/community-docs/community-articles/openvpn-2-6-manual.html)

---

## English quick start

MehrVPN is a self-hosted, bilingual OpenVPN administration panel. It bundles an unchanged pinned copy of `aminiyt1/openvpn-install`, and preserves its EasyRSA issuance/profile format. Run `sudo bash install.sh` from the extracted release on a supported VPS. No GitHub release or remote one-line installer is published yet.

Supported installation targets: Ubuntu 22.04/24.04 and Debian 12/13, systemd and working TUN. The initial HTTPS certificate is self-signed; verify its printed fingerprint, or replace it with a trusted domain certificate. Open the VPN and panel ports in your provider firewall.

Quotas count persisted OpenVPN payload upload + download bytes. A 2-second control loop enforces expiry/quotas and disconnect hooks finalize accounting. Overshoot between checks and unsampled bytes during abrupt VPN/host crashes remain possible. Monitoring failure for over 15 seconds stops the VPN. Imported clients begin accounting at panel installation. This release manages a single OpenVPN instance and has no WireGuard or reseller ownership isolation.

Use `scripts/backup.sh` for authenticated encrypted backups and `scripts/upgrade.sh` from a new release for upgrades. Both interrupt connections. The panel is an initial server-testing release: automated application checks pass, but an actual Linux installation and external VPN connection must pass `docs/ACCEPTANCE.md` before production use.
