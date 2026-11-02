# 🔮 Dejavou: Stealth In-Memory Multiplexed Reverse Tunnel

[![Go Version](https://img.shields.io/badge/Go-1.24+-00ADD8?style=flat&logo=go)](https://golang.org)
[![Platform](https://img.shields.io/badge/Platform-Linux%20%7C%20Windows-blue?style=flat&logo=linux)](https://github.com/fer000n/dejavou)
[![Architecture](https://img.shields.io/badge/Arch-x86__64-lightgrey?style=flat)](https://github.com/fer000n/dejavou)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://github.com/fer000n/dejavou/blob/main/LICENSE)
[![Stealth](https://img.shields.io/badge/Execution-Fileless%20RAM-red.svg)](https://github.com/fer000n/dejavou)

---

## 🇮🇷 معرفی پروژه به زبان فارسی (Persian Introduction)

**دژاوو (Dejavou)** یک راه‌کار پیشرفته، سبک و امن برای برقراری تونل‌های معکوس رمزنگاری‌شده (Reverse Tunnel) میان سرورهای داخل و خارج از کشور است. این پروژه از یک لانچر اختصاصی در حافظه (**DejavouLauncher**) بهره می‌برد که پروسه تونل را بدون ثبت فایل اجرایی روی دیسک، مستقیماً در رم (In-Memory / Fileless) اجرا می‌کند.

### 🌟 ویژگی‌های برجسته:
- **🛡️ اجرای ناشناس و مخفی در رم (Linux `memfd_create`):**
  - باینری اجرایی مستقیماً در رم بارگذاری شده و با فلگ‌های `F_ADD_SEALS` به صورت کاملاً غیرقابل تغییر پلمپ می‌شود.
  - هیچ ردی از باینری در حال اجرا روی هارد دیسک سرور ثبت نمی‌شود.
  - ضد دامپینگ حافظه: با فعال‌سازی `prctl(PR_SET_DUMPABLE, 0)` و `madvise(MADV_DONTDUMP)`، امکان استخراج باینری از طریق Memory Dump مسدود می‌گردد.
- **🚀 پشتیبانی از انواع پروتکل‌های ترنسپورت (Transports):**
  - **`tcp`**: سریع‌ترین ارتباط مستقیم با کمترین پینگ و اورهد.
  - **`ws` / `wss`**: وب‌سوکت ساده و وب‌سوکت امن TLS برای عبور از CDNها و فایروال‌های پیشرفته.
  - **`xhttp` / `xhttps`**: فناوری Split-HTTP با پشتیبانی از مدهای `packet-up` و `stream-up` (طراحی ویژه جهت عبور از CDNهای بافردار نظیر **ابر آروان** و **کلودفلر**).
- **🔒 رمزنگاری امن فریم‌به‌فریم (AES-256-GCM):**
  - کلیه بسته‌های ارسالی با کلید اشتراکی امن (PSK) رمزنگاری می‌شوند.
- **🌐 پروکسی SOCKS5 و Port Forwarding داخلی:**
  - بدون نیاز به نرم‌افزار جانبی، یک ساکس ۵ لوکال در اختیار کاربر قرار می‌دهد.
- **🔮 پشتیبانی از چندین تونل همزمان (Multi-Tunnel):**
  - راه‌اندازی هر تعداد تونل همزمان روی یک سرور با پورت‌ها و کانفیگ‌های مستقل.
  - مدیریت خودکار و پایدار با **Systemd Template Unit** (`dejavou@<name>.service`) با بالا آمدن خودکار پس از ریستارت سرور.
- **⚡ ویزارد تعاملی ترمینال (`dejavou.sh`):**
  - مدیریت صفر تا صد ساخت، ویرایش، حذف، مشاهده لاگ زنده و تست پینگ و IP خروجی بدون نیاز به دستورات پیچیده.
- **📦 باینری‌های آماده در ریپازیتوری:**
  - بدون نیاز به کامپایل، باینری‌های لینوکس و ویندوز آماده در این مخزن قرار داده شده‌اند.

---

### 🚀 شروع سریع در اوبونتو / دبیان (Quick Start)

کافیست در سرور لینوکس خود دستورات زیر را وارد کنید:

```bash
# ۱) کلون مخزن
git clone https://github.com/fer000n/dejavou.git
cd dejavou

# ۲) دادن مجوز اجرا و اجرای ویزارد به عنوان root
chmod +x dejavou.sh
sudo ./dejavou.sh
```

---

## 🇬🇧 English Documentation

**Dejavou** is a hardened reverse tunnel system paired with an anonymous in-memory loader (`DejavouLauncher`). Engineered for resilient edge-to-cloud connectivity across restrictive network topologies and aggressive DPI firewalls.

### Key Architecture:
- **Fileless Linux Execution:** Allocates an anonymous file descriptor via `SYS_memfd_create` (319) with `MFD_CLOEXEC | MFD_ALLOW_SEALING`. The memory is sealed immutable with `fcntl(F_ADD_SEALS)` and executed directly via `/proc/self/fd/<fd>`.
- **Anti-Forensic Protection:** Core dumpability disabled via `prctl(PR_SET_DUMPABLE, 0)` and RAM dump prevention via `madvise(MADV_DONTDUMP)`.
- **Multiplexed Secure Streams:** Lightweight connection pooling (`mux`) wrapping AES-256-GCM authenticated frames.
- **Multi-Tunnel Systemd Integration:** Isolated multi-instance template service (`dejavou@<tunnel_name>.service`) ensuring 100% crash resilience and auto-start on boot.
- **Zero Telemetry / No License Locks:** 100% free, offline, and self-contained.

---

## 📐 Architecture Overview

```text
+--------------------------------------------------------------------------+
|                        Client Node (Behind NAT/Iran)                     |
|                                                                          |
|   User Apps / Xray ──▶ SOCKS5 (127.0.0.1:10810)                          |
|                                │                                         |
|                       Dejavou Mux + AES-256-GCM                          |
|                                │                                         |
|                   Encrypted Carrier Pool (XHTTP/WSS)                     |
+────────────────────────────────┼─────────────────────────────────────────+
                                 │
                     [ Public Internet / CDN Edge ]
                                 │
+────────────────────────────────▼─────────────────────────────────────────+
|                        Server Node (Egress/Kharej)                       |
|                                                                          |
|                 Listener Carrier (0.0.0.0:39444)                         |
|                                │                                         |
|                       Dejavou Demux + Decrypt                            |
|                                │                                         |
|   Direct WAN Outbound ◀────────┴────────▶ Port Forwards (SSH, DB, Web)   |
+--------------------------------------------------------------------------+
```

---

## 📦 Repository Structure

```text
dejavou/
├── DejavouLauncher_linux    # Ready-to-run Linux in-memory stealth launcher
├── revtun-linux-amd64       # Ready-to-run Linux tunnel core
├── DejavouLauncher.exe      # Windows launcher
├── revtun.exe               # Windows tunnel core
├── dejavou.sh               # Interactive Ubuntu/Debian management wizard
├── config.go                # Dejavou launcher configuration parser
├── env.go                   # Environment variable loader
├── main.go                  # CLI entrypoint
├── memfd_linux.go           # Linux memfd_create & fcntl seals
├── memfd_other.go           # Cross-platform fallback runner
├── payload.go               # In-memory binary loader
├── go.mod                   # Go module definition
├── USAGE.md                 # Detailed configuration & troubleshooting guide
└── README.md                # Project documentation
```

---

## 🛠️ Interactive Wizard (`dejavou.sh`)

The easiest way to manage tunnels on Ubuntu/Debian:

```bash
chmod +x dejavou.sh
sudo ./dejavou.sh
```

```text
  ==============================================================
             🔮  DEJAVOU - Multi-Tunnel Stealth Manager  🔮     
              In-Memory Linux Anonymous Reverse Tunnel          
  ==============================================================

 System Status: [ 2 Active / Running | 2 Total Configured ]

  [1] List All Tunnels & Status
  [2] Create New Tunnel (Interactive Wizard)
  [3] Control Tunnels (Start / Stop / Restart)
  [4] Stream Live Tunnel Logs
  [5] Edit Tunnel Configuration
  [6] Test Connection & Exit Public IP
  [7] Delete a Tunnel
  [8] Reinstall / Refresh Binaries
  [0] Exit Wizard
```

---

## ⚙️ Configuration Profiles

### 1. Server Configuration (`server.json`)
Placed on the foreign / egress server:
```json
{
  "mode": "server",
  "transport": "tcp",
  "psk": "YOUR_STRONG_RANDOM_PSK_KEY",
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

### 2. Client Configuration (`client.json`)
Placed on the local / ingress server:
```json
{
  "mode": "client",
  "transport": "tcp",
  "psk": "YOUR_STRONG_RANDOM_PSK_KEY",
  "log_level": "info",
  "paths": [
    {
      "addr": "SERVER_PUBLIC_IP:7000",
      "transport": "tcp",
      "connection_pool": 2,
      "retry_interval": 3,
      "dial_timeout": 10
    }
  ],
  "socks5": {
    "enabled": true,
    "bind": "127.0.0.1:10810"
  },
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
```

---

## 🌐 ArvanCloud & Cloudflare CDN Setup (`xhttp`)

When tunneling through request-buffering CDNs:

#### Client Side:
```json
{
  "mode": "client",
  "transport": "xhttp",
  "psk": "YOUR_STRONG_RANDOM_PSK_KEY",
  "paths": [
    {
      "addr": "CDN_EDGE_IP:2083",
      "transport": "xhttp",
      "path": "/api",
      "mode": "packet-up",
      "host": "yourdomain.com",
      "connection_pool": 4
    }
  ],
  "socks5": {
    "enabled": true,
    "bind": "127.0.0.1:10810"
  }
}
```

---

## 🔄 Multi-Tunnel Systemd Template Units

Manage independent tunnels simultaneously:

```bash
# Enable on boot
systemctl enable dejavou@tunnel1
systemctl enable dejavou@tunnel2

# Start / Restart
systemctl start dejavou@tunnel1
systemctl restart dejavou@tunnel1

# Inspect live logs
journalctl -u dejavou@tunnel1 -f -n 50
```

---

## 🧪 Testing Connectivity

Test exit public IP through the SOCKS5 proxy:
```bash
curl -x socks5h://127.0.0.1:10810 https://api.ipify.org
```

---

## ⚖️ License

Released under the **MIT License**.
