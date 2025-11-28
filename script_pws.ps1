# Init params of scripts
param(
    [string]$actix_log, 
    [string]$nginx_access_log, 
    [string]$nginx_error_log
)

# Show Script is working
Write-Host "Starting script"

# Verify if all params are informed
if (-not $actix_log -or -not $nginx_access_log -or -not $nginx_error_log) {
    throw "Usage: $PSCommandPath -actix_log <actix_log> -nginx_access <nginx_access_log> -nginx_error
<nginx_error_log>"
}

# Init Variables of logs absolute paths 
$ACTIX_LOG = Resolve-Path -Path $actix_log
$NGINX_ACCESS_LOG = Resolve-Path -Path $nginx_access_log
$NGINX_ERROR_LOG = Resolve-Path -Path $nginx_error_log

# Filtering most frequents "200 | GET" requests of ACTIX_LOG
# Except png, ico, css and js extensions
# And keep only those that have been done more than 10 times
$MOST_SERVED = Get-Content -Path $ACTIX_LOG |
    Select-String "200 \| GET" |
    ForEach-Object {$_.Line.Split()[7]} | 
    Select-String "\.png|\.ico|\.css|\.js" -NotMatch |
    Sort-Object | Group-Object |
    Sort-Object -Property Count |
    Where-Object {$_.Count -gt 10} |
    ForEach-Object {"$($_.Name) : $($_.Count)"}

# Add this requests on a txt files 
$MOST_SERVED | Set-Content "most_served.txt"

# Add IPS to a blacklist from NGINX_ACCESS_LOG
# IPS blacklisted are those who tried to access admin, debug, login or .git
$IP_BLACKLISTS = Get-Content -Path $NGINX_ACCESS_LOG |
    Select-String "admin|debug|login|\.git" |
    ForEach-Object {$_.Line.Split()[0]} |
    Sort-Object | Group-Object |
    ForEach-Object {$_.Name}

# Add this blacklist to a txt file
$IP_BLACKLISTS | Set-Content "ip_blacklists.txt"

# Add more IPS who don't do GET, POST or HEAD
$IP_BLACKLISTS = Get-Content -Path $NGINX_ACCESS_LOG |
    Select-String "GET|POST|HEAD" -NotMatch |
    ForEach-Object {$_.Line.Split()[0]} |
    Sort-Object | Group-Object |
    ForEach-Object {$_.Name}

# Add the second list to the txt file
$IP_BLACKLISTS | Add-Content "ip_blacklists.txt"

# Create DOWNTIME variable to detect where nginx isn't able to discuss with actix_web
# We keep the date and hour of the error and add "DOWN"
$DOWNTIME = Get-Content -Path $NGINX_ERROR_LOG |
    Select-String "111: Unknown error" |
    ForEach-Object {$DATE = $_.Line.Split()[0]
                    $HEURE = $_.Line.Split()[1]
                    "$DATE $HEURE DOWN"
                    }

# Creating regex of Date and Time to detect them in logs
$DATE_REGEX = "([0-9]{4})-([0-9]{2})-([0-9]{2})"
$TIME_REGEX = "([0-9]{2}):([0-9]{2}):([0-9]{2})"

# Getting Captures groups of Date and Hours of NGINX_ERROR_LOG with regexs
# We keep the date and hour and add "UP"
$UPTIME = Get-Content -Path $ACTIX_LOG | Select-String "$DATE_REGEX.$TIME_REGEX" | ForEach-Object {
    $YEAR = $_.Matches.Groups[1].Value
    $MONTH = $_.Matches.Groups[2].Value
    $DAY = $_.Matches.Groups[3].Value

    $HOUR = $_.Matches.Groups[4].Value
    $MINUTE = $_.Matches.Groups[5].Value
    $SECOND = $_.Matches.Groups[6].Value

    "${YEAR}/${MONTH}/${DAY} ${HOUR}:${MINUTE}:${SECOND} UP"
}

# Creating variable "state" which represents the state of the previous line
$state = "DOWN"

# Creating variable "TEMP" withe DOWNTIME and UPTIME
$TEMP = $DOWNTIME + $UPTIME

# Sorting TEMP by Dates and getting the date, hour, and actual state ("UP" or "DOWN") of each line
# Verifying if actual state = "UP" and previous = "DOWN", if yes, Writing the date, hour, and "UP", and put "state" = "UP"
# else if actual state = "DOWN" and previous = "UP", Writing the date, hour, and "DOWN" + put "state" = "DOWN"
$TEMP | Sort-Object |
    ForEach-Object {
        $date = $_.Split()[0]
        $hour = $_.Split()[1]
        $actual = $_.Split()[2]
        if ($actual -eq "UP" -and $state -eq "DOWN") {
            "$date $hour UP"
            $state = "UP"
        } elseif ($actual -eq "DOWN" -and $state -eq "UP") {
            "$date $hour DOWN"
            $state = "DOWN"
        } 
    } | Format-Table
