#!/bin/bash
#
# systemd-flatline-lab
# Post-Engagement Cleanup & LAB-ONLY Stealth Simulation Edition
#
# WARNING — LAB USE ONLY
#
# This tool is for authorized SOC/blue-team testing and adversary simulation
# inside controlled, isolated lab environments ONLY.
# - REQUIRED: /etc/systemd-flatline-lab must exist on the host.
# - REQUIRED: set LAB_MODE=1 in the environment to enable lab features.
# - REQUIRED: pass --force to perform destructive actions.
# - REQUIRED: Type the exact phrase "I AM AUTHORIZED LAB OPERATOR" when prompted.
#
# Unauthorized use may be illegal. The script enforces multiple checks and
# will refuse to run stealth features if these requirements are not met.
#
# Author: wickednull (modified)
# Date: 2025-11-24
#

set -euo pipefail
IFS=$'\n\t'

# ----------------------------
# Configuration / Globals
# ----------------------------
LOG_DIR="/tmp/systemd-flatline-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/systemd-flatline.log"
REPORT_FILE="$LOG_DIR/systemd-flatline-report.asc"
ARCHIVE_FILE="$LOG_DIR/systemd-flatline-archive.tar"
ARCHIVE_ENC="$ARCHIVE_FILE.gpg"
SANDBOX_DIR="/tmp/systemd-flatline-sandbox"
LAB_FLAG_FILE="/etc/systemd-flatline-lab"

DRY_RUN="true"
FORCE="false"
DO_ARCHIVE="false"
DO_STEALTH_SIM="false"
GPG_RECIPIENT=""
USE_SYMMETRIC="true"
ZENITY_UI="true"
LAB_MODE_ENV="${LAB_MODE:-0}"

# ----------------------------
# Helpers
# ----------------------------
log_action() {
    echo "[$(date +%FT%T%z)] $1" | tee -a "$LOG_FILE"
}

fatal() { echo "FATAL: $*" >&2; log_action "FATAL: $*"; exit 1; }

usage() {
    cat <<EOF
Usage: $0 [--force] [--archive] [--recipient <gpg-id>] [--no-gui] [--stealth-sim] [--help]

--force         : perform destructive actions (otherwise dry-run)
--archive       : create encrypted archive of selected artifacts before deletion
--recipient ID  : GPG recipient to encrypt archive (if omitted, prompts for passphrase)
--no-gui        : run in CLI mode (no zenity)
--stealth-sim   : enable LAB-ONLY stealth simulation features (requires lab mode checks)
--help          : this message
EOF
}

# ----------------------------
# Arg parsing
# ----------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force) FORCE="true"; DRY_RUN="false"; shift ;;
        --archive) DO_ARCHIVE="true"; shift ;;
        --recipient) GPG_RECIPIENT="$2"; USE_SYMMETRIC="false"; shift 2 ;;
        --no-gui) ZENITY_UI="false"; shift ;;
        --stealth-sim) DO_STEALTH_SIM="true"; shift ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown arg: $1"; usage; exit 2 ;;
    esac
done

# ----------------------------
# Lab-mode safety checks
# ----------------------------
lab_checks() {
    # Require explicit lab flags
    if [[ "$DO_STEALTH_SIM" != "true" ]]; then
        return 0
    fi

    log_action "Requested stealth-simulation features."

    if [[ ! -f "$LAB_FLAG_FILE" ]]; then
        fatal "Lab flag file $LAB_FLAG_FILE not found. Stealth features disabled. To enable, create the file on the lab host."
    fi

    if [[ "$LAB_MODE_ENV" != "1" ]]; then
        fatal "Environment variable LAB_MODE=1 is required to enable stealth features."
    fi

    if [[ "$FORCE" != "true" ]]; then
        fatal "Stealth features require --force to be passed (explicit destructive consent)."
    fi

    # Double interactive typed confirmation
    CONF_PROMPT="I AM AUTHORIZED LAB OPERATOR"
    if [[ "$ZENITY_UI" == "true" ]]; then
        ANSWER=$(zenity --entry --title="LAB Authorization Required" --text="To enable LAB stealth features, type exactly:\n\n$CONF_PROMPT" ) || fatal "User cancelled."
    else
        read -r -p "Type exactly to enable LAB stealth features: $CONF_PROMPT  : " ANSWER
    fi
    if [[ "$ANSWER" != "$CONF_PROMPT" ]]; then
        fatal "Incorrect confirmation phrase typed. Aborting stealth enable."
    fi

    log_action "Lab checks passed. Stealth-simulation features enabled (LAB MODE)."
}

# ----------------------------
# User choices (GUI or CLI)
# ----------------------------
confirm_and_get_choices() {
    if [[ "$ZENITY_UI" == "true" ]]; then
        SELECTION=$(zenity --list --title="systemd-flatline (LAB)" --text="Select tasks:" \
          --checklist --column="Select" --column="Task" \
          TRUE "Clear User Activity History" \
          TRUE "Scrub Text-Based System Logs" \
          TRUE "Wipe systemd Journalctl Logs" \
          TRUE "Clean Temporary Files & Cache" \
          TRUE "Flush Network Caches" \
          TRUE "Perform a Dry-Run (No changes)" \
          --separator=":" --width=600 --height=380) || exit 0
        if [[ "$SELECTION" == *"Perform a Dry-Run"* ]]; then
            DRY_RUN="true"; FORCE="false"
        else
            DRY_RUN="false"; FORCE="true"
        fi
        CHOICES=()
        IFS=":" read -r -a TMP_CHOICES <<< "$SELECTION"
        for choice in "${TMP_CHOICES[@]}"; do
            if [[ "$choice" != "Perform a Dry-Run (No changes)" ]]; then
                CHOICES+=("$choice")
            fi
        done
    else
        CHOICES=("Clear User Activity History" "Scrub Text-Based System Logs" "Wipe systemd Journalctl Logs" "Clean Temporary Files & Cache" "Flush Network Caches")
    fi
}

# ----------------------------
# Archiving (encrypted)
# ----------------------------
create_encrypted_archive() {
    log_action "[*] Preparing encrypted archive of selected artifacts..."
    mkdir -p "$SANDBOX_DIR"
    ARGS=()

    [[ -d /var/log/journal ]] && ARGS+=("/var/log/journal")
    for f in /var/log/auth.log /var/log/syslog /var/log/wtmp /var/log/btmp /var/log/lastlog; do
        [[ -e "$f" ]] && ARGS+=("$f")
    done
    ARGS+=("/root/.bash_history" "/root/.zsh_history" "$HOME/.bash_history" "$HOME/.zsh_history")
    [[ -e /etc/ssh/sshd_config ]] && ARGS+=("/etc/ssh/sshd_config")

    # Deduplicate
    ARGS=($(printf "%s\n" "${ARGS[@]}" | awk '!x[$0]++'))

    if [[ ${#ARGS[@]} -eq 0 ]]; then
        log_action "No artifacts found to archive."
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "    (Dry-Run) Would create tar of: ${ARGS[*]}"
        return 0
    fi

    tar -C / -cf "$ARCHIVE_FILE" "${ARGS[@]/#//}" || fatal "tar failed"
    if [[ "$USE_SYMMETRIC" == "true" ]]; then
        read -rsp "Enter symmetric passphrase to encrypt archive (will not echo): " PASSPHRASE
        echo
        printf "%s" "$PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo AES256 -o "$ARCHIVE_ENC" "$ARCHIVE_FILE"
        shred -u "$ARCHIVE_FILE" || true
        log_action "Archive created and symmetrically encrypted at: $ARCHIVE_ENC"
    else
        if ! gpg --list-keys "$GPG_RECIPIENT" >/dev/null 2>&1; then
            fatal "GPG recipient $GPG_RECIPIENT not found."
        fi
        gpg --yes --output "$ARCHIVE_ENC" --encrypt --recipient "$GPG_RECIPIENT" "$ARCHIVE_FILE"
        shred -u "$ARCHIVE_FILE" || true
        log_action "Archive encrypted to recipient $GPG_RECIPIENT at: $ARCHIVE_ENC"
    fi
}

# ----------------------------
# Safe (sandboxed) stealth-simulation features
# These operate on copies inside $SANDBOX_DIR, never touching originals unless
# the user explicitly chooses a destructive action AND lab checks passed.
# ----------------------------
simulate_timestomp_on_copies() {
    log_action "[*] Creating sandbox copies for timestomp simulation..."
    rm -rf "$SANDBOX_DIR"
    mkdir -p "$SANDBOX_DIR"
    FILES_TO_COPY=()

    [[ -d /var/log/journal ]] && FILES_TO_COPY+=("/var/log/journal")
    for f in /var/log/auth.log /var/log/syslog /var/log/wtmp /var/log/btmp /var/log/lastlog; do
        [[ -e "$f" ]] && FILES_TO_COPY+=("$f")
    done
    FILES_TO_COPY=($(printf "%s\n" "${FILES_TO_COPY[@]}" | awk '!x[$0]++'))

    if [[ ${#FILES_TO_COPY[@]} -eq 0 ]]; then
        log_action "No files found to copy for timestomp simulation."
        return 0
    fi

    # Copy preserving attributes to sandbox
    for src in "${FILES_TO_COPY[@]}"; do
        dest="$SANDBOX_DIR$(dirname "$src")"
        mkdir -p "$dest"
        if [[ -d "$src" ]]; then
            cp -a "$src" "$dest/" || true
        else
            cp -a "$src" "$dest/" || true
        fi
    done

    # Apply timestomp simulation: set timestamps randomly within a lab window
    log_action "[*] Applying timestomp (sandbox copies only)..."
    for f in $(find "$SANDBOX_DIR" -type f); do
        # choose a random date within the last 30 days (lab demonstration)
        offset=$(( RANDOM % (30*24*3600) ))
        target_ts=$(date -d "@$(( $(date +%s) - offset ))" +%Y%m%d%H%M.%S)
        touch -m -t "$target_ts" "$f" || true
    done
    log_action "[+] Timestomp simulation complete. (Sandbox only: $SANDBOX_DIR)"
}

spawn_dummy_processes() {
    log_action "[*] Spawning benign dummy processes with randomized argv0 (lab demo)..."
    # Launch 3 short-lived dummy processes (sleep) with randomized argv0 using bash exec -a
    for i in 1 2 3; do
        RAND_NAME="labproc_$RANDOM"
        # Launch in background for demonstration (longer-lived)
        bash -c "exec -a $RAND_NAME sleep 3600" &
        pid=$!
        log_action "    Spawned dummy process '$RAND_NAME' PID=$pid"
    done
    log_action "[+] Dummy process demo launched. (Kill PIDs manually when done.)"
}

simulate_service_interruptions() {
    log_action "[*] Simulating service interruption events (audit-only)..."
    # We will not stop real services unless user explicitly requests a real test.
    # Create a simulated-events file describing what would be done.
    SIMFILE="$LOG_DIR/simulated_service_events.txt"
    {
        echo "Simulated service interruption events"
        echo "Timestamp: $(date -u --iso-8601=seconds)"
        echo "Service: sshd"
        echo "Action: simulated stop -> wait -> simulated start"
        echo "Note: This is a simulation; no services were stopped by default."
    } > "$SIMFILE"
    log_action "Simulation events written to: $SIMFILE"
}

# ----------------------------
# Real destructive journal wipe (only if FORCE and lab checks passed OR user explicitly consent for real wipe)
# ----------------------------
wipe_journalctl_real() {
    log_action "[*] Performing REAL journalctl wipe (destructive)..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "    (Dry-Run) Would wipe systemd journal"
        return 0
    fi
    systemctl stop systemd-journald || log_action "Warning: could not stop journald; continuing cautiously."
    rm -rf /var/log/journal/* || true
    rm -rf /run/log/journal/* || true
    journalctl --rotate || true
    journalctl --vacuum-size=1K || true
    journalctl --vacuum-time=1s || true
    systemctl start systemd-journald || true
    log_action "[+] Real journalctl wipe complete."
}

# ----------------------------
# Reuse previously defined functions for text scrub, temp cleanup, network flush
# (kept minimal and safe)
# ----------------------------
scrub_text_logs() {
    log_action "[*] Scrubbing classic text-based logs (truncate)..."
    FILES=(/var/log/auth.log /var/log/syslog /var/log/wtmp /var/log/btmp /var/log/lastlog)
    for f in "${FILES[@]}"; do
        if [[ -e "$f" ]]; then
            if [[ "$DRY_RUN" == "true" ]]; then
                log_action "    (Dry-Run) Would truncate $f"
            else
                truncate -s 0 "$f" || true
                log_action "    Truncated $f"
            fi
        fi
    done
    log_action "[+] Text log scrubbing complete."
}

clean_user_history() {
    log_action "[*] Cleaning user activity history..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "    (Dry-Run) Would clear shell/editor history and recent files"
    else
        history -c || true
        rm -f /root/.bash_history /root/.zsh_history "$HOME/.bash_history" "$HOME/.zsh_history" || true
        rm -f /root/.viminfo /root/.nano_history "$HOME/.viminfo" "$HOME/.nano_history" || true
        rm -f "$HOME/.local/share/recently-used.xbel" || true
    fi
    log_action "[+] User history cleanup complete."
}

clean_temp_files() {
    log_action "[*] Cleaning temporary files and cache..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "    (Dry-Run) Would clean /tmp, thumbnails, and trash"
    else
        rm -rf /tmp/* || true
        rm -rf "$HOME/.cache/thumbnails"/* || true
        rm -rf "$HOME/.local/share/Trash"/* || true
    fi
    log_action "[+] Temp cleanup complete."
}

flush_network_caches() {
    log_action "[*] Flushing network caches..."
    if [[ "$DRY_RUN" == "true" ]]; then
        log_action "    (Dry-Run) Would flush ARP and DNS caches"
    else
        ip -s -s neigh flush all || true
        command -v systemd-resolve &>/dev/null && systemd-resolve --flush-caches || true
        command -v resolvectl &>/dev/null && resolvectl flush-caches || true
    fi
    log_action "[+] Network cache flush complete."
}

# ----------------------------
# Report generation & signing
# ----------------------------
generate_and_sign_report() {
    {
        echo "systemd-flatline-lab report"
        echo "Timestamp: $(date -u --iso-8601=seconds)"
        echo "Host: $(hostname -f)"
        echo "User: $(whoami)"
        echo "Dry-run: $DRY_RUN"
        echo "Force: $FORCE"
        echo "Lab-mode-env: $LAB_MODE_ENV"
        echo "Stealth-sim requested: $DO_STEALTH_SIM"
        echo "Archive encrypted: ${ARCHIVE_ENC:-none}"
        echo
        echo "Log file: $LOG_FILE"
        echo "Sandbox dir: $SANDBOX_DIR"
        echo
        echo "Notes:"
        echo "  - This tool performed sandboxed stealth simulations only unless 'real wipe' actions were explicitly selected and lab checks passed."
    } > "${REPORT_FILE}.tmp"

    if [[ "$DRY_RUN" == "true" ]]; then
        mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
        log_action "Dry-run report written to: $REPORT_FILE"
    else
        if gpg --list-secret-keys >/dev/null 2>&1; then
            gpg --clearsign -o "$REPORT_FILE" "${REPORT_FILE}.tmp" && rm -f "${REPORT_FILE}.tmp"
            log_action "Signed report created at: $REPORT_FILE"
        else
            mv "${REPORT_FILE}.tmp" "$REPORT_FILE"
            log_action "Report created (unsigned) at: $REPORT_FILE (no local GPG key)"
        fi
    fi
}

# ----------------------------
# Main flow
# ----------------------------
if [[ $EUID -ne 0 ]]; then
   if [[ "$ZENITY_UI" == "true" ]]; then
       zenity --error --title="systemd-flatline-lab" --text="This script must be run as root."
   else
       echo "This script must be run as root." >&2
   fi
   exit 1
fi

if [[ "$ZENITY_UI" == "true" ]]; then
    zenity --question --title="systemd-flatline-lab: WARNING" --text="This tool is LAB-ONLY. Read the script header before continuing." --width=600
    [[ $? -ne 0 ]] && fatal "User cancelled."
fi

confirm_and_get_choices

if [[ "$DO_STEALTH_SIM" == "true" ]]; then
    lab_checks
fi

log_action "Starting run. dry_run=$DRY_RUN force=$FORCE stealth_sim=$DO_STEALTH_SIM"

# Archive first if requested
if [[ "$DO_ARCHIVE" == "true" ]]; then
    create_encrypted_archive
fi

# Execute selected tasks
for task in "${CHOICES[@]}"; do
    case "$task" in
        "Clear User Activity History") clean_user_history ;;
        "Scrub Text-Based System Logs") scrub_text_logs ;;
        "Wipe systemd Journalctl Logs")
            if [[ "$DO_STEALTH_SIM" == "true" ]]; then
                # In lab mode, offer sandboxed timestomp simulation and optionally real wipe
                simulate_timestomp_on_copies
                simulate_service_interruptions
                spawn_dummy_processes
                # If real destructive wipe is desired (and allowed by lab_checks), ask again
                if [[ "$FORCE" == "true" ]]; then
                    if [[ "$ZENITY_UI" == "true" ]]; then
                        if zenity --question --title="REAL Journal Wipe" --text="You enabled LAB mode. Do you want to perform a REAL journalctl wipe on the host? This is destructive." --width=600; then
                            if zenity --entry --title="Final Confirm: type REAL WIPE to proceed" --text="Type EXACTLY: REAL WIPE" | grep -q "REAL WIPE"; then
                                wipe_journalctl_real
                            else
                                log_action "User aborted final real-wipe confirmation."
                            fi
                        fi
                    else
                        read -r -p "Perform real journalctl wipe now? (yes/no): " yn
                        if [[ "$yn" == "yes" ]]; then
                            read -r -p "Type EXACTLY 'REAL WIPE' to proceed: " code
                            if [[ "$code" == "REAL WIPE" ]]; then
                                wipe_journalctl_real
                            else
                                log_action "Final confirmation failed. Skipping real wipe."
                            fi
                        fi
                    fi
                fi
            else
                # Normal behavior for non-stealth runs
                wipe_journalctl_real
            fi
            ;;
        "Clean Temporary Files & Cache") clean_temp_files ;;
        "Flush Network Caches") flush_network_caches ;;
        *) log_action "Unknown task: $task" ;;
    esac
done

generate_and_sign_report

# Show results to user
if [[ "$ZENITY_UI" == "true" ]]; then
    zenity --text-info --title="systemd-flatline-lab: Report" --filename="$REPORT_FILE" --width=700 --height=500
else
    echo "Report: $REPORT_FILE"
    echo "Log: $LOG_FILE"
fi

log_action "Completed. Logs in $LOG_DIR"
exit 0