# راهنمای جامع استفاده از DaggerLauncher (User Guide)

این راهنما نحوه راه‌اندازی، تنظیم و اجرای تونل با استفاده از لانچر اختصاصی **DaggerLauncher** را توضیح می‌دهد.

---

## ۱. معرفی و مزایای DaggerLauncher

لانچر **DaggerLauncher** یک اجراکننده امن در حافظه (In-Memory Loader) برای موتور تونل است.  
ویژگی‌های کلیدی:
- **اجرای در رم بدون ردپا روی دیسک (Linux `memfd_create`):** باینری بدون ذخیره شدن روی هارد، مستقیماً در یک فایل دیسکریپتور ناشناس داخل رم لود و قفل (`Sealed`) شده و اجرا می‌شود.
- **حفاظت در برابر مهندسی معکوس و Memory Dump:** غیرفعال‌سازی Core Dump با `prctl` و مسدودسازی دامپ حافظه با `madvise(MADV_DONTDUMP)`.
- **بدون لایسنس و محدودیت:** کاملاً آفلاین و مستقیم عمل کرده و هیچ وابستگی به سرور خارجی یا لایسنس ندارد.

---

## ۲. پیش‌نیازها

برای اجرا، فایل اجرایی موتور تونل (`revtun` یا `revtun.exe`) باید در کنار لانچر یا در پوشه `dist` یا والد قرار داشته باشد:
```text
daggerlauncher/
├── DaggerLauncher_linux   (نسخه لینوکس)
├── DaggerLauncher.exe     (نسخه ویندوز)
├── revtun                 (موتور تونل برای لینوکس)
└── revtun.exe             (موتور تونل برای ویندوز)
```

---

## ۳. فرمت فایل کانفیگ (JSON)

برای اجرا، یک فایل با پسوند `.json` می‌سازید و آدرس آن را با آرگومان `-c` به برنامه می‌دهید:

### سناریو الف: سرور خارج (Server / Egress)
این سرور به اینترنت آزاد متصل است و ترافیک را به بیرون هدایت می‌کند.

**نمونه کانفیگ سرور (`server.json`):**
```json
{
  "mode": "server",
  "transport": "tcp",
  "psk": "کلید_رمزنگاری_دلخواه_و_طولانی",
  "log_level": "info",
  "listeners": [
    {
      "addr": "0.0.0.0:7000",
      "transport": "tcp",
      "ports": ["2222=22"]
    }
  ],
  "socks5": {
    "enabled": true,
    "bind": "127.0.0.1:10808"
  },
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
```

---

### سناریو ب: کلاینت ایران (Client / Ingress)
این سرور داخل ایران است، به سرور خارج وصل شده و پورت SOCKS5 یا پورت‌های فوروارد شده را در اختیار شما قرار می‌دهد.

**نمونه کانفیگ کلاینت (`client.json`):**
```json
{
  "mode": "client",
  "transport": "tcp",
  "psk": "کلید_رمزنگاری_دلخواه_و_طولانی",
  "log_level": "info",
  "paths": [
    {
      "addr": "IP_SERVER_KHAREJ:7000",
      "transport": "tcp",
      "connection_pool": 2,
      "retry_interval": 3,
      "dial_timeout": 10
    }
  ],
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
```

---

## ۴. انواع ترنسپورت‌ها (Transports)

| نوع ترنسپورت | مقدار در کانفیگ | کاربرد و ویژگی |
| :--- | :--- | :--- |
| **TCP** | `"tcp"` | بیشترین سرعت، کمترین اورهد (مناسب ارتباط مستقیم بین سرورها) |
| **WebSocket** | `"ws"` | وب‌سوکت ساده برای سازگاری با پروکسی‌های وب |
| **WebSocket TLS** | `"wss"` | وب‌سوکت امن با TLS برای عبور از CDNها و فایروال‌ها |
| **HTTP** | `"http"` | بر بستر درخواست‌های استاندارد HTTP |
| **XHTTP** | `"xhttp"` | تکنولوژی Split-HTTP با مدهای `stream-up` و `packet-up` (مخصوص CDNهایی با بافرینگ مثل ArvanCloud و Cloudflare) |
| **XHTTPS** | `"xhttps"` | نسخه امن XHTTP بر بستر TLS |

### نمونه تنظیم XHTTP از پشت CDN (آروان / کلودفلر):
در بخش `paths` کلاینت:
```json
{
  "addr": "edge-ip.arvancloud.ir:2083",
  "transport": "xhttp",
  "path": "/api-v1",
  "mode": "packet-up",
  "host": "yourdomain.com"
}
```

---

## ۵. نحوه اجرا

### در لینوکس (Linux):
```bash
# پرمیشن اجرا
chmod +x DaggerLauncher_linux

# اجرا با کانفیگ
./DaggerLauncher_linux -c server.json
```

### در ویندوز (Windows):
```powershell
.\DaggerLauncher.exe -c client.json
```

---

## ۶. راه‌اندازی به عنوان سرویس پس‌زمینه خودکار (Systemd در لینوکس)

برای اینکه برنامه همیشه فعال بماند و پس از ریبوت سیستم خودکار بالا بیاید:

۱. فایل سرویس را در مسیر `/etc/systemd/system/dagger.service` بسازید:
```ini
[Unit]
Description=DaggerLauncher Stealth Tunnel
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/dagger
ExecStart=/opt/dagger/DaggerLauncher_linux -c /opt/dagger/config.json
Restart=always
RestartSec=3
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
```

۲. فعال‌سازی و استارت سرویس:
```bash
systemctl daemon-reload
systemctl enable --now dagger

# مشاهده وضعیت و لاگ‌ها
systemctl status dagger
journalctl -u dagger -f
```

---

## ۷. عیب‌یابی رایج (FAQ)

1. **خطای `carrier down: read ack (wrong PSK?)`:**
   - مقدار فیلد `"psk"` در کلاینت و سرور یکسان نیست یا یکی از طرفین دستکاری شده است.
2. **خطای `unknown transport ""`:**
   - فیلد `"transport"` را در ریشه کانفیگ یا درون شیء `paths` / `listeners` قرار دهید (مثلاً `"transport": "tcp"`).
3. **خطای `no executable payload binary found`:**
   - فایل موتور تونل (`revtun` یا `revtun.exe`) باید در کنار فایل لانچر یا پوشه پروژه باشد.

