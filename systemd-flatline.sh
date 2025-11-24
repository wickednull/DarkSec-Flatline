#!/bin/bash
#
# systemd-flatline
# Post-Engagement Cleanup Script (Journalctl-Wiping Edition)
#
# Author: wickednull
# Date: 2025-11-22
#

LOG_FILE="/tmp/cleanup.log"

log_action() {
    echo "$1" >> "$LOG_FILE"
    echo "$1"
}

clean_user_history() {
    log_action "[*] Cleaning user activity history..."
    if [ "$DRY_RUN" = "false" ]; then
        history -c
        rm -f ~/.bash_history ~/.zsh_history ~/.history
        rm -f ~/.viminfo ~/.nano_history
        rm -f ~/.local/share/recently-used.xbel
    else
        log_action "    (Dry-Run) Would clear shell/editor history and recent files"
    fi
    log_action "[+] User activity history cleanup complete."
}

scrub_logs() {
    log_action "[*] Scrubbing classic /var/log text logs..."
    if [ "$DRY_RUN" = "false" ]; then
        truncate -s 0 /var/log/auth.log
        truncate -s 0 /var/log/syslog
        truncate -s 0 /var/log/wtmp
        truncate -s 0 /var/log/btmp
        truncate -s 0 /var/log/lastlog
    else
        log_action "    (Dry-Run) Would truncate common log files under /var/log/"
    fi
    log_action "[+] Text-based log scrubbing complete."
}

scrub_journalctl() {
    log_action "[*] Wiping systemd journal logs (journalctl)..."

    if [ "$DRY_RUN" = "false" ]; then
        systemctl stop systemd-journald

        rm -rf /var/log/journal/*
        rm -rf /run/log/journal/*

        journalctl --rotate
        journalctl --vacuum-size=1K
        journalctl --vacuum-time=1s

        systemctl start systemd-journald
    else
        log_action "    (Dry-Run) Would stop systemd-journald"
        log_action "    (Dry-Run) Would delete /var/log/journal/*"
        log_action "    (Dry-Run) Would delete /run/log/journal/*"
        log_action "    (Dry-Run) Would vacuum journalctl storage"
        log_action "    (Dry-Run) Would restart systemd-journald"
    fi

    log_action "[+] Journalctl wiping complete."
}

clean_temp_files() {
    log_action "[*] Cleaning temporary files and cache..."
    if [ "$DRY_RUN" = "false" ]; then
        rm -rf /tmp/* ~/.cache/thumbnails/* ~/.local/share/Trash/*
    else
        log_action "    (Dry-Run) Would clean /tmp, thumbnail cache, and trash"
    fi
    log_action "[+] Temporary file cleanup complete."
}

flush_network_caches() {
    log_action "[*] Flushing network caches..."
    if [ "$DRY_RUN" = "false" ]; then
        ip -s -s neigh flush all
        command -v systemd-resolve &>/dev/null && systemd-resolve --flush-caches
        command -v resolvectl &>/dev/null && resolvectl flush-caches
    else
        log_action "    (Dry-Run) Would flush ARP and DNS caches"
    fi
    log_action "[+] Network cache flushing complete."
}

# --- Main ---
if [[ $EUID -ne 0 ]]; then
   zenity --error --title="systemd-flatline" --text="This script must be run as root."
   exit 1
fi

zenity --question --title="systemd-flatline: Disclaimer" \
    --text="This script will permanently delete system logs, including systemd journals. Continue?" \
    --width=300
[[ $? -ne 0 ]] && exit 0

CHOICES=$(zenity --list \
  --title="systemd-flatline" \
  --text="Select cleanup tasks:" \
  --checklist \
  --column="Select" --column="Task" \
  TRUE  "Clear User Activity History" \
  TRUE  "Scrub Text-Based System Logs" \
  TRUE  "Wipe systemd Journalctl Logs" \
  TRUE  "Clean Temporary Files & Cache" \
  TRUE  "Flush Network Caches" \
  FALSE "Perform a Dry-Run (No changes)" \
  --separator=":" --width=450 --height=350)

[[ -z "$CHOICES" ]] && exit 0

DRY_RUN="false"
[[ "$CHOICES" == *"Dry-Run"* ]] && DRY_RUN="true"

(
    echo "Cleanup Log" > "$LOG_FILE"
    echo "---------------------" >> "$LOG_FILE"

    [[ "$DRY_RUN" = "true" ]] && log_action "[!] --- DRY RUN ENABLED ---"

    [[ "$CHOICES" == *"Clear User Activity History"* ]] && clean_user_history
    [[ "$CHOICES" == *"Scrub Text-Based System Logs"* ]] && scrub_logs
    [[ "$CHOICES" == *"Wipe systemd Journalctl Logs"* ]] && scrub_journalctl
    [[ "$CHOICES" == *"Clean Temporary Files & Cache"* ]] && clean_temp_files
    [[ "$CHOICES" == *"Flush Network Caches"* ]] && flush_network_caches

    log_action "[*] All selected tasks complete."

) | zenity --progress --title="systemd-flatline" \
    --text="Executing tasks..." --pulsate --auto-close

zenity --text-info --title="systemd-flatline: Report" \
    --filename="$LOG_FILE" --width=600 --height=400

rm -f "$LOG_FILE"
exit 0