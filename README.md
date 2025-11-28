# 📂 Log Analysis and Reporting Script (PowerShell)

This project provides a PowerShell script designed to analyze three specific log files from a web application environment (an Actix web server behind an NGINX reverse proxy). The script performs log filtering, creates blacklists, and determines application uptime/downtime periods.

## 🚀 Execution

To execute the script, you must have the three required log files (`actix.log`, `nginx_access.log`, and `nginx_error.log`) located in a subdirectory named `logs` relative to the script's location.

### Prerequisites

* A Windows environment with **PowerShell** (version 5.1 or later recommended).

### Usage

1.  Navigate to the directory containing the script (`script_pws.ps1`).
2.  Run the script, providing the relative paths to the log files using the specified parameters:

    ```bash
    .\script_pws.ps1 -actix_log .\logs\actix.log -nginx_access_log .\logs\nginx_access.log -nginx_error_log .\logs\nginx_error.log
    ```

    > **Note:** The script will throw an error and display the correct usage if any parameter is missing.

## 📋 Script Functionality Overview

The `script_pws.ps1` performs four main tasks:

### 1. Most Served Resources (`most_served.txt`)

This section analyzes the **Actix log** (`actix.log`) to identify the most frequently requested static resources.

* It filters for successful **HTTP 200** responses using the **GET** method.
* It **excludes** requests for common static file types: `.png`, `.ico`, `.css`, and `.js`.
* It counts the occurrences of each unique path.
* It only includes resources that have been served **more than 10 times**.
* The results are saved to a file named `most_served.txt` in the format `[RESOURCE_PATH] : [COUNT]`.

### 2. IP Blacklisting (`ip_blacklists.txt`)

This section analyzes the **NGINX access log** (`nginx_access.log`) to compile a list of suspicious IP addresses. The process involves two steps:

* **Initial Blacklist:** Identifies IPs that requested sensitive or restricted paths (e.g., `admin`, `debug`, `login`, or `.git` directory attempts).
* **Second Blacklist:** Identifies IPs whose requests **do not** use common HTTP methods (`GET`, `POST`, or `HEAD`), suggesting potentially malicious or unconventional scanning activity.
* The unique IP addresses from both checks are combined and saved/appended to the file `ip_blacklists.txt`.

### 3. Application Downtime Detection

This section attempts to determine the periods when the Actix server was unavailable, as reflected by the NGINX error log, and match them with Actix log activity.

* **Downtime Events (`DOWNTIME`):** It searches the **NGINX error log** (`nginx_error.log`) for the specific error message `"111: Unknown error"`, which typically indicates NGINX was unable to connect to the upstream (Actix) server. These events are marked with a state of **"DOWN"**.
* **Uptime Events (`UPTIME`):** It extracts the timestamp from lines in the **Actix log** (`actix.log`) using a specific date/time regex. These events are marked with a state of **"UP"**.

### 4. State Change Report (Console Output)

The script combines the `DOWNTIME` and `UPTIME` events, sorts them chronologically, and then generates a report of all **state changes** (transitions from UP to DOWN or DOWN to UP).

* The initial state is assumed to be **"DOWN"**.
* The final output is a table printed to the console, showing the **Date**, **Time**, and the **New State** (`UP` or `DOWN`) for every detected transition. This provides a clear timeline of the application's availability.