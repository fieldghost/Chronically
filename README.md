
<img width="642" height="829" alt="screenshot-2026-04-23_00-13-44" src="https://github.com/user-attachments/assets/1a217bb0-887c-49c4-9265-d2db11c533e3" />

# Unicron

> "Because I keep forgetting the god damn command to use crontab."

**Unicron** is a pure Bash CLI tool designed to simplify system administration, file management, and automated backups. It acts as an interactive wrapper around `cron`, allowing you to schedule jobs using plain time formats (like `14:00`), securely manage files, and update your system—all without having to memorize complex syntax.


---

## Features

* **Interactive CLI & Menu:** Run the script without arguments to get a full interactive menu. Forget a parameter? The script will dynamically prompt you for missing paths, timestamps, or multi-line text input.
* **Non-Interactive Mode:** Use the `--non-interactive` flag to bypass all prompts and fail-fast, making it perfectly suited for CI/CD pipelines or headless automation.
* **Human-Readable Scheduling:** Schedule backup and archive jobs using a standard `HH:MM` format.
* **Smart Cron Deduplication:** Seamlessly appends new jobs to your crontab. The engine hashes your jobs and tags them (e.g., `# unicron:hash`), preventing duplicate entries and preventing crontab spam.
* **Automated Backups & Archives:** Uses `tar` to quietly compress and back up specified directories, safely tagging the filename with the dynamic day of the week to allow for proper rotation.
* **Universal System Updates:** Auto-detects your system's package manager (`apt`, `pacman`, `dnf`, `yum`, `zypper`, `apk`, `xbps`, `emerge`, `nix`, or `brew`) to update and upgrade your system gracefully.
* **Secure File Management:** Create, append/overwrite (with multi-line support), and delete files safely. Includes hardcoded guardrails that refuse to delete critical system directories (like `/bin`, `/etc`, `/var`, or `/`).
* **Security-First Design:** Features strict POSIX-compliant quoting to eliminate command injection risks and a smart `run_privileged` wrapper that intelligently handles `sudo` prompts depending on the user's EUID and interaction mode.

---

## Installation

Clone the repository and make the scripts executable:

```bash
git clone git@github.com:fieldghost/unicron.git
cd unicron/scripts
chmod +x unicron.sh executecron.sh
```

---

## Usage

You can run the script via the main menu, with all arguments inline, or non-interactively.

**Main Menu:**
```bash
./unicron.sh
```

**Inline execution:**
```bash
./unicron.sh backup /path/to/source /path/to/destination 14:00
```
*(If you leave out an argument, the script will prompt you for the missing information).*

**Non-Interactive execution (Automation):**
```bash
./unicron.sh --non-interactive update
```

**Supported commands:**
* `backup` : Schedule a rotating tarball backup.
* `archive` : Schedule a rotating tarball archive.
* `update` : Refresh system package repositories.
* `upgrade` : Upgrade installed system packages.
* `file-create` : Safely create a new file and directory path.
* `file-update` : Interactively overwrite or append multi-line content to a file.
* `file-delete` : Delete a file (protected against system directory deletion).

---

## Architecture

To keep things clean, secure, and modular, the tool is split into two components:
* **`unicron.sh`**: The front-end interface. It handles user input, path validation (including expanding `~` and stripping trailing slashes), smart privilege escalation, and interactive prompts.
* **`executecron.sh`**: The back-end scheduling engine. It builds perfectly escaped shell strings, calculates stable job ID hashes for deduplication, and safely modifies your system's crontab without breaking existing entries.

---

## License

This project is licensed under the MIT License.
