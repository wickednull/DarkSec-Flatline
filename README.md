# DarkSec-Flatline

  _____           _      ____            __   _      __     _
 |  __ \         | |    / __ \          / _| | |    / _|   | |    (_)
 | |  | |  _   _ | | __ | |  | |  _ __  | |_  | |_  | |_  __| | ___ _  ___
 | |  | | | | | || |/ / | |  | | | '_ \ |  _| | __| |  _|/ _` |/ __|| | __|
 | |__| | | |_| ||   <  | |__| | | | | || |   | |_  | | | (_| |\__ \| |\__ \
 |_____/   \__,_||_|\_\  \____/  |_| |_||_|    \__| |_|  \__,_||___/|_||___/

** A Post-Engagement Cleanup Utility for Security Professionals

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Made with Bash](https://img.shields.shields.io/badge/Made%20with-Bash-1f425f.svg)](https://www.gnu.org/software/bash/)

---

DarkSec-Flatline is a post-engagement cleanup utility designed for penetration testers, red teamers, and security professionals. It provides a simple and effective GUI-based method to remove traces of activity from a Linux workstation, helping to ensure operational security and digital hygiene.

## ♰️ Disclaimer

**This is a powerful tool that permanently deletes data from your system.** The authors are not responsible for any data loss or damage caused by the use of this script. **Use with extreme caution.** It is highly recommended to run the "Dry-Run" option first to understand what actions will be performed.

## Features

- **GUI-Based Operation:** Uses `zenity` to provide a user-friendly checklist of cleaning tasks.
- **Selective Cleaning:** Choose exactly which cleanup tasks to perform.
- **User History Removal:** Clears shell history (`bash`, `zsh`), editor history (`vim`, `nano`), and recent file lists.
- **System Log Scrubbing:** Truncates critical system logs like `auth.log`, `syslog`, and others.
- **Temporary File & Cache Deletion:** Wipes `/tmp`, user thumbnail caches, and the trash directory.
- **Network Cache Flushing:** Clears the system's ARP and DNS caches.
- **Safe Dry-Run Mode:** Simulate a cleanup operation without making any actual changes to the system, providing a report of actions that would have been taken.
- **Root-Required:** Includes a check to ensure it is run with the necessary privileges.

## Requirements

- A Debian/Ubuntu-based Linux distribution (due to specific log paths and utilities).
- `bash`
- `zenity` (to render the GUI)
- `sudo` / root privileges

To install `zenity` on a Debian-based system:
```bash
sudo apt-get update
sudo apt-get install zenity
```

## Installation

No complex installation is required. Simply clone this repository or download the `darksec-flatline.sh` script.

```bash
git clone https://github.com/YourUsername/DarkSec-Flatline.git
cd DarkSec-Flatline
```

Then, make the script executable:
```bash
chmod +x darksec-flatline.sh
```

## Usage

The script must be run with root privileges.

```bash
sudo ./darksec-flatline.sh
```

1.  A disclaimer will appear. You must agree to continue.
2.  The main menu will load, presenting a checklist of available cleanup tasks.
3.  Select the desired tasks and click "OK". It is highly recommended to leave **"Perform a Dry-Run"** checked for your first run.
4.  A progress bar will show that the tasks are being executed.
5.  Upon completion, a report will be displayed summarizing all actions performed.

<!--
## Screenshots

*Add screenshots of the GUI dialogs here to showcase the user interface.*

**Main Menu:**
![Main Menu](link-to-screenshot.png)

**Final Report:**
![Final Report](link-to-screenshot.png)
-->

## How It Works

The script modularizes its cleaning operations into several distinct functions:

| Function | Description |
| :--- | :--- |
| `clean_user_history` | Removes traces of user commands and file access by deleting `~/.bash_history`, `~/.zsh_history`, `~/.viminfo`, `~/.nano_history`, and `~/.local/share/recently-used.xbel`. |
| `scrub_logs` | Scrubs system-level logs by truncating them to zero bytes. This includes `/var/log/auth.log`, `/var/log/syslog`, `/var/log/wtmp`, `/var/log/btmp`, and `/var/log/lastlog`. |
| `clean_temp_files` | Cleans temporary files and caches by recursively deleting the contents of `/tmp`, `~/.cache/thumbnails`, and `~/.local/share/Trash`. |
| `flush_network_caches` | Removes network-related artifacts by flushing the system's ARP cache (`ip -s -s neigh flush all`) and DNS cache (using `systemd-resolve` or `resolvectl`). |

All actions are logged to `/tmp/cleanup.log`, which is displayed in the final report and then securely deleted.

## Contributing

Contributions are welcome! If you have suggestions for improvements or new features, please feel free to:

1.  Fork the repository.
2.  Create a new feature branch (`git checkout -b feature/AmazingFeature`).
3.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4.  Push to the branch (`git push origin feature/AmazingFeature`).
5.  Open a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
*This script was authored by Gemini CLI.*
