# Chronically

> "Because I keep forgetting the god damn command to use crontab."

**Chronically** is a pure Bash CLI tool designed to simplify scheduling automated tasks and backups. It acts as an interactive wrapper around `cron`, allowing you to schedule jobs using plain time formats (like `14:00`) instead of trying to remember if the asterisk goes in the minute, hour, or day column.

🔗 **[View on GitHub](https://github.com/fieldghost/Chronically)**

---

## ✨ Features

* **Interactive CLI:** Forget an argument? No problem. The script will dynamically prompt you for missing paths and timestamps.
* **Human-Readable Time:** Schedule jobs using a standard `HH:MM` format.
* **Safe Scheduling:** Seamlessly appends new jobs to your crontab without overwriting your existing entries.
* **Automated Backups:** Uses `tar` to quietly compress and back up specified directories, tagging the filename with the current day of the week.
* *(Coming Soon)*: Skeletons are in place for system updates, upgrades, and file manipulation scheduling.

---

## 🛠️ Installation

Clone the repository and make the scripts executable:

```bash
git clone git@github.com:fieldghost/Chronically.git
cd Chronically/scripts
chmod +x autocron.sh executecron.sh
```

---

## 💻 Usage

You can run the script with all arguments inline, or just trigger the command and let the interactive prompts guide you.

**Inline execution:**
```bash
./autocron.sh backup /path/to/source /path/to/destination 14:00
```

**Interactive execution:**
```bash
./autocron.sh backup
```
*(The script will detect the missing arguments and prompt you for the source directory, destination directory, and time).*

**Current supported commands:**
* `backup` (Fully functional)
* `archive`, `update`, `upgrade`, `file-create`, `file-update`, `file-delete` (Placeholders/WIP)

---

## 🏗️ Architecture

To keep things clean and modular, the tool is split into two components:
* **`autocron.sh`**: The front-end interface. It handles user input, path validation (including expanding `~` to your home directory), and interactive prompts.
* **`executecron.sh`**: The back-end engine. It takes the validated data, converts the timestamp into `cron` syntax, and safely injects the job into your system's crontab.

---

## 📄 License

This project is licensed under the MIT License.
