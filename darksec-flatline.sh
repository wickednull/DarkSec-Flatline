#!/bin/bash
#
# Post-Engagement Cleanup Script
#
# This script provides a GUI for cleaning up a penetration testing workstation
# after an engagement. It is designed to be safe, with a dry-run mode and
# clear user confirmation prompts.
#
# Author: Gemini CLI
# Date: 2025-11-22
#

# --- Configuration ---

# Log file for recording actions
LOG_FILE="/tmp/cleanup.log"

# --- Functions ---

# Function to log messages to both stdout and the log file
log_action() {
    echo "$1" >> "$LOG_FILE"
    echo "$1"
}

# Function to clean user activity history
clean_user_history() {
    log_action "[*] Cleaning user activity history..."
    if [ "$DRY_RUN" = "false" ]; then
        # Clear shell history
        history -c
        rm -f ~/.bash_history ~/.zsh_history ~/.history

        # Clear editor history
        rm -f ~/.viminfo ~/.nano_history

        # Clear recent files
        rm -f ~/.local/share/recently-used.xbel
    else
        log_action "    (Dry-Run) Would clear shell history (bash, zsh)"
        log_action "    (Dry-Run) Would clear editor history (vim, nano)"
        log_action "    (Dry-Run) Would clear recent files"
    fi
    log_action "[+] User activity history cleanup complete."
}

# Function to scrub system logs
scrub_logs() {
    log_action "[*] Scrubbing system logs..."
    if [ "$DRY_RUN" = "false" ]; then
        # Clear auth.log, syslog, etc.
        truncate -s 0 /var/log/auth.log
        truncate -s 0 /var/log/syslog
        truncate -s 0 /var/log/wtmp
        truncate -s 0 /var/log/btmp
        truncate -s 0 /var/log/lastlog
    else
        log_action "    (Dry-Run) Would truncate /var/log/auth.log"
        log_action "    (Dry-Run) Would truncate /var/log/syslog"
        log_action "    (Dry-Run) Would truncate /var/log/wtmp"
        log_action "    (Dry-Run) Would truncate /var/log/btmp"
        log_action "    (Dry-Run) Would truncate /var/log/lastlog"
    fi
    log_action "[+] System log scrubbing complete."
}

# Function to clean temporary files and cache
clean_temp_files() {
    log_action "[*] Cleaning temporary files and cache..."
    if [ "$DRY_RUN" = "false" ]; then
        # Clean /tmp
        rm -rf /tmp/*

        # Clean thumbnail cache
        rm -rf ~/.cache/thumbnails/*

        # Empty trash
        rm -rf ~/.local/share/Trash/*
    else
        log_action "    (Dry-Run) Would clean /tmp"
        log_action "    (Dry-Run) Would clean thumbnail cache"
        log_action "    (Dry-Run) Would empty trash"
    fi
    log_action "[+] Temporary file and cache cleanup complete."
}

# Function to flush network caches
flush_network_caches() {
    log_action "[*] Flushing network caches..."
    if [ "$DRY_RUN" = "false" ]; then
        # Flush ARP cache
        ip -s -s neigh flush all

        # Flush DNS cache
        if command -v systemd-resolve &> /dev/null; then
            systemd-resolve --flush-caches
        fi
        if command -v resolvectl &> /dev/null; then
            resolvectl flush-caches
        fi
    else
        log_action "    (Dry-Run) Would flush ARP cache"
        log_action "    (Dry-Run) Would flush DNS cache"
    fi
    log_action "[+] Network cache flushing complete."
}

# --- Main Script ---

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
   zenity --error --title="DarkSec-Flatline" --text="This script must be run as root."
   exit 1
fi

# Display warning and get confirmation
zenity --question --title="DarkSec-Flatline: Disclaimer" --text="This script is designed to permanently remove data from your system. Are you sure you want to continue?" --width=300
if [ $? -ne 0 ]; then
    zenity --info --title="DarkSec-Flatline" --text="Operation cancelled by user."
    exit 0
fi

# Main GUI checklist
CHOICES=$(zenity --list \
  --title="DarkSec-Flatline" \
  --text="Select the cleaning tasks to perform:" \
  --checklist \
  --column="Select" --column="Task" \
  TRUE "Clear User Activity History" \
  TRUE "Scrub System Logs" \
  TRUE "Clean Temporary Files & Cache" \
  TRUE "Flush Network Caches" \
  FALSE "Perform a Dry-Run (No changes will be made)" \
  --separator=":" --width=450 --height=300)

# Check if the user cancelled
if [ -z "$CHOICES" ]; then
    zenity --info --title="DarkSec-Flatline" --text="Operation cancelled by user."
    exit 0
fi

# Parse choices
DRY_RUN="false"
if [[ "$CHOICES" == *"Perform a Dry-Run"* ]]; then
    DRY_RUN="true"
fi

# Execute selected tasks
(
    # Initialize log file
    echo "Cleanup Log" > "$LOG_FILE"
    echo "---------------------" >> "$LOG_FILE"

    if [ "$DRY_RUN" = "true" ]; then
        log_action "[!] --- Performing a Dry-Run ---"
    fi

    if [[ "$CHOICES" == *"Clear User Activity History"* ]]; then
        clean_user_history
    fi
    if [[ "$CHOICES" == *"Scrub System Logs"* ]]; then
        scrub_logs
    fi
    if [[ "$CHOICES" == *"Clean Temporary Files & Cache"* ]]; then
        clean_temp_files
    fi
    if [[ "$CHOICES" == *"Flush Network Caches"* ]]; then
        flush_network_caches
    fi

    log_action "[*] All selected tasks complete."

) | zenity --progress --title="DarkSec-Flatline: Cleaning in Progress..." --text="Executing tasks..." --pulsate --auto-close

# Display final report
if [ "$DRY_RUN" = "true" ]; then
    zenity --text-info --title="DarkSec-Flatline: Dry-Run Summary" --filename="$LOG_FILE" --width=600 --height=400
else
    zenity --text-info --title="DarkSec-Flatline: Cleanup Report" --filename="$LOG_fILE" --width=600 --height=400
fi

# Clean up the log file
rm -f "$LOG_FILE"

exit 0
