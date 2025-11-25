# DarkSec-Flatline
![image](https://github.com/user-attachments/assets/fab72aad-50d3-4046-b4aa-71f8579b249e)

**A Post-Engagement Cleanup Utility for Security Professionals**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Made with Bash](https://img.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)
[![Release](https://img.shields.io/github/v/release/wickednull/DarkSec-Flatline?label=Latest%20Release)](https://github.com/wickednull/DarkSec-Flatline/releases)
[![Stars](https://img.shields.io/github/stars/wickednull/DarkSec-Flatline?style=social)](https://github.com/wickednull/DarkSec-Flatline/stargazers)
[![Forks](https://img.shields.io/github/forks/wickednull/DarkSec-Flatline?style=social)](https://github.com/wickednull/DarkSec-Flatline/network/members)
[![OS](https://img.shields.io/badge/OS-Linux-blue)](https://www.linux.org/)
[![Version](https://img.shields.io/badge/version-2.0-blueviolet)](https://github.com/wickednull/DarkSec-Flatline/releases)

---

DarkSec-Flatline is a post-engagement cleanup utility designed for penetration testers, red teamers, and security professionals. It provides simple and effective methods to remove traces of activity from a Linux workstation, helping ensure operational security and digital hygiene. This repository contains three scripts:

- `darksec-flatline` – Basic cleanup (CLI)
- `systemd-flatline` – Advanced GUI cleanup
- `systemd-flatline-lab` – LAB-only stealth cleanup for SOC/lab testing

---

## ♰️ Disclaimer

These scripts are **powerful and can permanently delete or modify data**.  

- **`darksec-flatline`**: Safe basic cleanup  
- **`systemd-flatline`**: GUI-based advanced cleanup; always use Dry-Run first  
- **`systemd-flatline-lab`**: LAB-only version with stealth simulation, timestomping, dummy processes, and optional `journalctl` wiping. **Must only be used in authorized lab environments**  

The authors are not responsible for any data loss or damage caused by use. **Use with extreme caution.**

---

## Features

**Common Features (`darksec-flatline` & `systemd-flatline`)**  
- GUI-Based Operation (`zenity` for `systemd-flatline`)  
- Selective Cleaning  
- User History Removal (`bash`, `zsh`, `vim`, `nano`, recent files)  
- System Log Scrubbing (`auth.log`, `syslog`, `wtmp`, `btmp`, `lastlog`)  
- Temporary File & Cache Deletion (`/tmp`, thumbnails, trash)  
- Network Cache Flushing (ARP & DNS)  
- Safe Dry-Run Mode  
- Root Privileges Check  

**Lab-Only Features (`systemd-flatline-lab`)**  
- Stealth-Simulation: timestomping, dummy processes, service interruptions  
- Lab Safety Checks: authorization phrase, lab-mode flag, multiple confirmations  
- Artifact Archiving: optional GPG-encrypted logs  
- Audit-Logged Simulation: signed report for SOC testing  
- Optional Real Journal Wipe (LAB-only)

---

## Requirements

- Debian/Ubuntu-based Linux distribution  
- `bash`  
- `zenity` (for GUI scripts)  
- `sudo` / root privileges  

Install `zenity` if missing:

```bash
sudo apt-get update
sudo apt-get install zenity
```

---

## Installation

```bash
git clone https://github.com/wickednull/DarkSec-Flatline.git
cd DarkSec-Flatline
chmod +x darksec-flatline
chmod +x systemd-flatline
chmod +x systemd-flatline-lab
```

---

## Usage

**Basic Version:**

```bash
sudo ./darksec-flatline
```

- Runs basic cleanup tasks  
- Supports Dry-Run mode  
- Simple CLI output

**GUI Version:**

```bash
sudo ./systemd-flatline
```

1. Confirm the disclaimer  
2. Select tasks from the GUI checklist (Dry-Run recommended first)  
3. View progress and final report

**Lab-Only Version:**

```bash
sudo LAB_MODE=1 ./systemd-flatline-lab --stealth-sim --force
```

- Requires lab-mode authorization file `/etc/systemd-flatline-lab`  
- Must type authorization phrase: `I AM AUTHORIZED LAB OPERATOR`  
- Optional artifact archiving: `--archive`  
- Simulation features only run after all lab checks pass  
- **Warning:** Always use in a controlled lab environment. Stealth features must not be run on production systems

---

## How It Works

- `clean_user_history` removes shell, editor, and recent file histories  
- `scrub_logs` truncates system-level logs  
- `clean_temp_files` deletes temporary files, caches, and trash  
- `flush_network_caches` clears ARP and DNS caches  
- Lab-only features (systemd-flatline-lab) include `simulate_timestomp_on_copies`, `spawn_dummy_processes`, `simulate_service_interruptions`, and `wipe_journalctl_real`  

All actions are logged to `/tmp/cleanup.log` and displayed in the final report (signed if GPG is available), then securely deleted.

---

## Contributing

Contributions are welcome! Fork, create a branch, commit changes, push, and open a Pull Request.

---

## License

MIT License

---

## Screenshots

**Main Menu:**  
![Main Menu](https://github.com/wickednull/DarkSec-Flatline/releases/latest/download/main_menu.png)

**Final Report:**  
![Final Report](https://github.com/wickednull/DarkSec-Flatline/releases/latest/download/final_report.png)
