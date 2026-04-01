#  Chronically

Pure Bash CLI tool designed to simplify scheduling automated tasks and backups via cron.

## Why?

Because I keep forgetting the god damn command to use crontab. 

##  Features

* **Interactive CLI:** Helps with missing arguments.
* **Safe Scheduling:** Appends new jobs to crontab without overwriting existing entries.
* **Automated Backups:** Uses tar to compresses specified directories.
* *(Coming Soon)* System updates and upgrade scheduling.

##  Installation

Clone the repository.
Make sure the scripts are executable:

```bash
git clone git@github.com:fieldghost/Chronically.git
cd Chronically/scripts
chmod +x autocron.sh executecron.sh
```

## How to

Run the main script and pass your desired command:

```bash
./autocron.sh backup /path/to/source /path/to/destination 14:00
```

If you omit arguments, the script will interactively prompt you for them.

##  "Architecture"

* `autocron.sh`: The main interface.
* `executecron.sh`: The backend engine.

##  License

This project is licensed under the MIT License.
