#!/usr/bin/env bash
# ==============================================================================
# DaggerLauncher & Revtun Interactive Wizard for Ubuntu / Debian
# سازنده و مدیریت خودکار تونل و لانچر Dagger
# ==============================================================================

set -e

# مسیرهای پیش‌فرض
INSTALL_DIR="/opt/dagger"
CONFIG_FILE="${INSTALL_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/dagger.service"
LAUNCHER_BIN="${INSTALL_DIR}/DaggerLauncher"
REVTUN_BIN="${INSTALL_DIR}/revtun"

# رنگ‌ها برای واسط کاربری ترمینال
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# بررسی دسترسی Root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}[!] این اسکریپت باید با دسترسی root اجرا شود (sudo -i).${NC}"
        exit 1
    fi
}

# نصب بسته‌های پایه مورد نیاز
install_deps() {
    local missing=()
    command -v jq >/dev/null 2>&1 || missing+=("jq")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v openssl >/dev/null 2>&1 || missing+=("openssl")
    command -v nano >/dev/null 2>&1 || missing+=("nano")

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${CYAN}[*] در حال نصب بسته‌های پیش‌نیاز (${missing[*]})...${NC}"
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq "${missing[@]}" >/dev/null 2>&1
    fi
}

# بنر هدر
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "  ========================================================"
    echo "       🗡️  DaggerLauncher & Revtun Management Wizard  🗡️   "
    echo "               مدیریت و پیکربندی تونل در اوبونتو          "
    echo "  ========================================================"
    echo -e "${NC}"
}

# بررسی وضعیت سرویس و پروسه
show_status() {
    show_header
    echo -e "${BOLD}=== [ بررسی وضعیت سیستم و تونل ] ===${NC}\n"

    # ۱. وضعیت باینری‌ها
    if [ -f "$LAUNCHER_BIN" ]; then
        echo -e "باینری لانچر:       ${GREEN}نصب شده (${LAUNCHER_BIN})${NC}"
    else
        echo -e "باینری لانچر:       ${RED}یافت نشد!${NC}"
    fi

    if [ -f "$REVTUN_BIN" ]; then
        echo -e "موتور اصلی تونل:    ${GREEN}نصب شده (${REVTUN_BIN})${NC}"
    else
        echo -e "موتور اصلی تونل:    ${RED}یافت نشد!${NC}"
    fi

    # ۲. وضعیت فایل کانفیگ
    if [ -f "$CONFIG_FILE" ]; then
        local mode transport psk
        mode=$(jq -r '.mode // "نامشخص"' "$CONFIG_FILE" 2>/dev/null || echo "نامشخص")
        transport=$(jq -r '.transport // "نامشخص"' "$CONFIG_FILE" 2>/dev/null || echo "نامشخص")
        echo -e "فایل کانفیگ:        ${GREEN}موجود است${NC} (نقش: ${CYAN}${mode}${NC} | ترنسپورت: ${YELLOW}${transport}${NC})"
    else
        echo -e "فایل کانفیگ:        ${YELLOW}تنظیم نشده است!${NC}"
    fi

    # ۳. وضعیت سرویس Systemd
    if systemctl is-active --quiet dagger 2>/dev/null; then
        local pid uptime_str
        pid=$(systemctl show -p MainPID --value dagger 2>/dev/null)
        echo -e "وضعیت سرویس:        ${GREEN}فعال و در حال اجرا (Active / Running)${NC} [PID: ${pid}]"
    else
        if [ -f "$SERVICE_FILE" ]; then
            echo -e "وضعیت سرویس:        ${RED}متوقف است (Inactive / Stopped)${NC}"
        else
            echo -e "وضعیت سرویس:        ${YELLOW}سرویس هنوز ایجاد نشده است${NC}"
        fi
    fi

    # ۴. بررسی پورت‌های فعال
    echo -e "\n${BOLD}پورت‌های فعال سیستم متعلق به تونل:${NC}"
    ss -tulpn 2>/dev/null | grep -E "revtun|dagger|Dagger" || echo "  (پورتی در حالت لیسن یافت نشد یا برنامه با نام مستعار اجرا شده است)"

    # ۵. آخرین خطوط لاگ
    echo -e "\n${BOLD}آخرین ۵ خط لاگ سرویس:${NC}"
    echo "--------------------------------------------------------"
    journalctl -u dagger -n 5 --no-pager 2>/dev/null || echo "لاگی ثبت نشده است."
    echo "--------------------------------------------------------"

    read -rp "برای بازگشت به منو Enter بزنید..."
}

# مشاهده لاگ زنده
show_live_logs() {
    show_header
    echo -e "${CYAN}[*] در حال نمایش لاگ زنده (جهت خروج Ctrl+C را بزنید)...${NC}\n"
    journalctl -u dagger -f -n 50
}

# ایجاد یا به‌روزرسانی سرویس Systemd
setup_systemd() {
    cat <<EOF > "$SERVICE_FILE"
[Unit]
Description=DaggerLauncher Stealth In-Memory Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=${INSTALL_DIR}
ExecStart=${LAUNCHER_BIN} -c ${CONFIG_FILE}
Restart=always
RestartSec=3
LimitNOFILE=1048576
StandardOutput=journal
StandardError=journal
SyslogIdentifier=dagger

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable dagger >/dev/null 2>&1
}

# ویزارد ساخت کانفیگ جدید
create_config_wizard() {
    show_header
    echo -e "${BOLD}=== [ ویزارد ساخت کانفیگ جدید ] ===${NC}\n"

    mkdir -p "$INSTALL_DIR"

    # ۱. انتخاب نقش
    echo -e "نقش این سرور را انتخاب کنید:"
    echo "  1) سرور خارج (Server / Egress - اینترنت آزاد / مقصد)"
    echo "  2) سرور ایران (Client / Ingress - متصل‌شونده / مبدا)"
    read -rp "گزینه (1 یا 2): " role_opt

    local mode="client"
    if [ "$role_opt" == "1" ]; then
        mode="server"
    fi

    # ۲. انتخاب ترنسپورت
    echo -e "\nنوع پروتکل ترنسپورت (Transport) را انتخاب کنید:"
    echo "  1) TCP       - ارتباط مستقیم TCP با نهایت سرعت (پیش‌فرض)"
    echo "  2) WS        - وب‌سوکت ساده"
    echo "  3) WSS       - وب‌سوکت امن با TLS"
    echo "  4) XHTTP     - اسپلیت HTTP (مخصوص عبور از CDN آروان/کلودفلر)"
    echo "  5) XHTTPS    - اسپلیت HTTP امن با TLS"
    read -rp "گزینه [پیش‌فرض 1]: " tr_opt

    local transport="tcp"
    case "$tr_opt" in
        2) transport="ws" ;;
        3) transport="wss" ;;
        4) transport="xhttp" ;;
        5) transport="xhttps" ;;
        *) transport="tcp" ;;
    esac

    # ۳. تنظیم کلید رمزنگاری PSK
    echo -e "\nکلید رمزنگاری اشتراکی (PSK):"
    local def_psk
    def_psk=$(openssl rand -hex 16)
    echo -e "  کلید تصادفی پیشنهادی: ${YELLOW}${def_psk}${NC}"
    read -rp "کلید دلخواه را وارد کنید یا Enter بزنید تا کلید بالا استفاده شود: " user_psk
    local psk="${user_psk:-$def_psk}"

    # اگر سرور خارج باشد
    if [ "$mode" == "server" ]; then
        read -rp "پورت لیسن سرور را وارد کنید [پیش‌فرض 7000]: " srv_port
        srv_port="${srv_port:-7000}"

        read -rp "آیا ساکس ۵ (SOCKS5) روی سرور فعال شود؟ (y/n) [پیش‌فرض y]: " socks_opt
        socks_opt="${socks_opt:-y}"

        local socks_enabled="false"
        local socks_bind="127.0.0.1:10808"
        if [[ "$socks_opt" =~ ^[Yy]$ ]]; then
            socks_enabled="true"
            read -rp "پورت بایند SOCKS5 [پیش‌فرض 10808]: " s_port
            s_port="${s_port:-10808}"
            socks_bind="127.0.0.1:${s_port}"
        fi

        # ساخت JSON سرور
        cat <<EOF > "$CONFIG_FILE"
{
  "mode": "server",
  "transport": "${transport}",
  "psk": "${psk}",
  "log_level": "info",
  "listeners": [
    {
      "addr": "0.0.0.0:${srv_port}",
      "transport": "${transport}"
    }
  ],
  "socks5": {
    "enabled": ${socks_enabled},
    "bind": "${socks_bind}"
  },
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
EOF

    # اگر سرور ایران (Client) باشد
    else
        read -rp "آدرس IP یا دامنه سرور خارج: " remote_ip
        while [ -z "$remote_ip" ]; do
            echo -e "${RED}[!] آدرس سرور الزامی است.${NC}"
            read -rp "آدرس IP یا دامنه سرور خارج: " remote_ip
        done

        read -rp "پورت سرور خارج [پیش‌فرض 7000]: " remote_port
        remote_port="${remote_port:-7000}"

        read -rp "تعداد کانکشن‌های همزمان (Connection Pool) [پیش‌فرض 2]: " pool_size
        pool_size="${pool_size:-2}"

        read -rp "آیا ساکس ۵ محلی (Local SOCKS5) باز شود؟ (y/n) [پیش‌فرض y]: " local_socks_opt
        local_socks_opt="${local_socks_opt:-y}"
        local socks_json=""
        if [[ "$local_socks_opt" =~ ^[Yy]$ ]]; then
            read -rp "پورت ساکس لوکال در ایران [پیش‌فرض 10810]: " ls_port
            ls_port="${ls_port:-10810}"
            socks_json="\"socks5\": { \"enabled\": true, \"bind\": \"127.0.0.1:${ls_port}\" },"
        fi

        # تنظیمات اختصاصی CDN اگر XHTTP باشد
        local extra_fields=""
        if [ "$transport" == "xhttp" ] || [ "$transport" == "xhttps" ]; then
            read -rp "مسیر URL برای XHTTP [پیش‌فرض /api]: " x_path
            x_path="${x_path:-/api}"
            read -rp "دامنه SNI/Host برای عبور از CDN (اختیاری): " x_host
            extra_fields="\"path\": \"${x_path}\", \"mode\": \"packet-up\","
            if [ -n "$x_host" ]; then
                extra_fields="${extra_fields} \"host\": \"${x_host}\","
            fi
        fi

        # ساخت JSON کلاینت
        cat <<EOF > "$CONFIG_FILE"
{
  "mode": "client",
  "transport": "${transport}",
  "psk": "${psk}",
  "log_level": "info",
  "paths": [
    {
      "addr": "${remote_ip}:${remote_port}",
      "transport": "${transport}",
      ${extra_fields}
      "connection_pool": ${pool_size},
      "retry_interval": 3,
      "dial_timeout": 10
    }
  ],
  ${socks_json}
  "advanced": {
    "auto_tune": true,
    "keepalive_sec": 5,
    "dead_timeout_sec": 25
  }
}
EOF
    fi

    echo -e "\n${GREEN}[✓] فایل کانفیگ با موفقیت در ${CONFIG_FILE} ذخیره شد.${NC}"
    setup_systemd

    read -rp "آیا مایلید سرویس هم‌اکنون استارت یا ری‌استارت شود؟ (y/n) [پیش‌فرض y]: " restart_opt
    restart_opt="${restart_opt:-y}"
    if [[ "$restart_opt" =~ ^[Yy]$ ]]; then
        systemctl restart dagger
        echo -e "${GREEN}[✓] سرویس با کانفیگ جدید ری‌استارت شد.${NC}"
    fi

    read -rp "برای ادامه Enter بزنید..."
}

# ویرایش دستی فایل کانفیگ
edit_config_manual() {
    show_header
    if [ ! -f "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}[!] فایل کانفیگ وجود ندارد. ابتدا با ویزارد یک کانفیگ ایجاد کنید.${NC}"
        read -rp "برای بازگشت Enter بزنید..."
        return
    fi

    # پشتیبان‌گیری
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    nano "$CONFIG_FILE"

    # بررسی صحت ساختار JSON
    if jq . "$CONFIG_FILE" >/dev/null 2>&1; then
        echo -e "${GREEN}[✓] ساختار JSON معتبر است.${NC}"
        read -rp "آیا سرویس ری‌استارت شود؟ (y/n) [پیش‌فرض y]: " r_opt
        r_opt="${r_opt:-y}"
        if [[ "$r_opt" =~ ^[Yy]$ ]]; then
            systemctl restart dagger
            echo -e "${GREEN}[✓] سرویس ری‌استارت شد.${NC}"
        fi
    else
        echo -e "${RED}[!] ساختار فایل JSON نامعتبر است! فایل به نسخه قبل بازگردانده می‌شود.${NC}"
        cp "${CONFIG_FILE}.bak" "$CONFIG_FILE"
    fi
    read -rp "برای ادامه Enter بزنید..."
}

# مدیریت وضعیت سرویس (استارت/استاپ/ری‌استارت)
manage_service() {
    show_header
    echo -e "${BOLD}=== [ مدیریت سرویس Systemd ] ===${NC}\n"
    echo "  1) ری‌استارت سرویس (Restart)"
    echo "  2) راه‌اندازی سرویس (Start)"
    echo "  3) توقف سرویس (Stop)"
    echo "  4) فعال‌سازی اجرای خودکار هنگام بوت (Enable)"
    echo "  5) غیرفعال‌سازی اجرای خودکار هنگام بوت (Disable)"
    echo "  0) بازگشت به منوی اصلی"
    read -rp "گزینه: " svc_opt

    case "$svc_opt" in
        1)
            systemctl restart dagger
            echo -e "${GREEN}[✓] سرویس ری‌استارت شد.${NC}"
            ;;
        2)
            systemctl start dagger
            echo -e "${GREEN}[✓] سرویس استارت شد.${NC}"
            ;;
        3)
            systemctl stop dagger
            echo -e "${YELLOW}[!] سرویس متوقف شد.${NC}"
            ;;
        4)
            systemctl enable dagger
            echo -e "${GREEN}[✓] اجرای خودکار در بوت فعال شد.${NC}"
            ;;
        5)
            systemctl disable dagger
            echo -e "${YELLOW}[!] اجرای خودکار در بوت غیرفعال شد.${NC}"
            ;;
        0) return ;;
        *) echo -e "${RED}گزینه نامعتبر است.${NC}" ;;
    esac
    sleep 1.5
}

# تست پینگ و اتصال پروکسی ساکس
test_connection() {
    show_header
    echo -e "${BOLD}=== [ تست و عیب‌یابی اتصال تونل ] ===${NC}\n"

    local socks_port
    socks_port=$(jq -r '.socks5.bind // empty' "$CONFIG_FILE" 2>/dev/null | awk -F: '{print $NF}')

    if [ -n "$socks_port" ]; then
        echo -e "در حال ارسال درخواست تست از طریق ساکس محلی (پورت ${socks_port})..."
        local ip_res
        ip_res=$(curl -s -m 6 -x "socks5h://127.0.0.1:${socks_port}" https://api.ipify.org 2>/dev/null || echo "")

        if [ -n "$ip_res" ]; then
            echo -e "${GREEN}[✓] تست موفقیت‌آمیز بود! IP خروجی تونل: ${BOLD}${ip_res}${NC}"
        else
            echo -e "${RED}[✕] ارتباط از طریق ساکس برقرار نشد.${NC}"
            echo -e "علت‌های احتمالی: متوقف بودن سرویس خارج، کلید PSK اشتباه، یا پورت مسدود."
        fi
    else
        echo -e "${YELLOW}[!] پورت ساکس ۵ در فایل کانفیگ فعال نشده است.${NC}"
    fi

    echo ""
    read -rp "برای بازگشت به منو Enter بزنید..."
}

# نصب یا انتقال باینری‌ها
install_binaries() {
    show_header
    echo -e "${BOLD}=== [ نصب و به‌روزرسانی باینری‌ها در سرور ] ===${NC}\n"
    mkdir -p "$INSTALL_DIR"

    # کپی باینری لانچر در صورت وجود در دایرکتوری جاری
    if [ -f "./DaggerLauncher_linux" ]; then
        cp "./DaggerLauncher_linux" "$LAUNCHER_BIN"
        chmod +x "$LAUNCHER_BIN"
        echo -e "${GREEN}[✓] فایل DaggerLauncher_linux کپی شد.${NC}"
    elif [ -f "./DaggerLauncher" ]; then
        cp "./DaggerLauncher" "$LAUNCHER_BIN"
        chmod +x "$LAUNCHER_BIN"
        echo -e "${GREEN}[✓] فایل DaggerLauncher کپی شد.${NC}"
    fi

    # کپی باینری revtun در صورت وجود
    if [ -f "./revtun-linux-amd64" ]; then
        cp "./revtun-linux-amd64" "$REVTUN_BIN"
        chmod +x "$REVTUN_BIN"
        echo -e "${GREEN}[✓] فایل revtun-linux-amd64 کپی شد.${NC}"
    elif [ -f "./revtun" ]; then
        cp "./revtun" "$REVTUN_BIN"
        chmod +x "$REVTUN_BIN"
        echo -e "${GREEN}[✓] فایل revtun کپی شد.${NC}"
    fi

    setup_systemd
    echo -e "${GREEN}[✓] باینری‌ها و سرویس آماده‌سازی شدند.${NC}"
    sleep 2
}

# حذف کامل سرویس
uninstall_service() {
    show_header
    echo -e "${RED}${BOLD}=== [ حذف سرویس DaggerLauncher ] ===${NC}\n"
    read -rp "آیا از حذف کامل سرویس و توقف تونل اطمینان دارید؟ (y/n): " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        systemctl stop dagger 2>/dev/null || true
        systemctl disable dagger 2>/dev/null || true
        rm -f "$SERVICE_FILE"
        systemctl daemon-reload
        echo -e "${YELLOW}[✓] سرویس متوقف و از Systemd حذف گردید.${NC}"
        echo -e "پوشه کانفیگ در ${INSTALL_DIR} باقی مانده است."
    fi
    sleep 2
}

# منوی اصلی
main_menu() {
    check_root
    install_deps

    while true; do
        show_header

        # نمایش وضعیت خلاصه در بالای منو
        if systemctl is-active --quiet dagger 2>/dev/null; then
            echo -e " وضعیت جاری: [ ${GREEN}● فعال و متصل (Running)${NC} ]\n"
        else
            echo -e " وضعیت جاری: [ ${RED}○ متوقف (Stopped)${NC} ]\n"
        fi

        echo "  1) مشاهده وضعیت دقیق سیستم و تونل (Status)"
        echo "  2) مشاهده زنده لاگ‌ها (Live Logs)"
        echo "  3) ساخت کانفیگ جدید با ویزارد گام‌به‌گام (New Config)"
        echo "  4) ویرایش دستی فایل کانفیگ (Edit JSON)"
        echo "  5) مدیریت وضعیت سرویس (Start / Stop / Restart)"
        echo "  6) تست ارتباط پروکسی و IP خروجی (Test Connection)"
        echo "  7) نصب و استقرار باینری‌ها (Install Binaries)"
        echo "  8) حذف سرویس از سیستم (Uninstall)"
        echo "  0) خروج از ویزارد (Exit)"
        echo ""
        read -rp "لطفاً شماره گزینه مورد نظر را وارد کنید: " choice

        case "$choice" in
            1) show_status ;;
            2) show_live_logs ;;
            3) create_config_wizard ;;
            4) edit_config_manual ;;
            5) manage_service ;;
            6) test_connection ;;
            7) install_binaries ;;
            8) uninstall_service ;;
            0)
                echo -e "\n${CYAN}روز خوش! خروج از ویزارد.${NC}\n"
                exit 0
                ;;
            *)
                echo -e "${RED}گزینه نامعتبر است. لطفاً عدد بین 0 تا 8 وارد کنید.${NC}"
                sleep 1
                ;;
        esac
    done
}

main_menu
