check_bacula
============

Checks Bacula backups per host in a specified timeframe, e.g. the last 24 hours.

### Usage

    -h              Display this helpmessage.
    --usage         Display the usage help
    -H | --host     The hostname of the backup host
    -w | --warning  The warning threshold, if number of backups found in db is smaller than this value state WARNING is returned -c | --critical The critical threshold, if number of backups found in db is smaller than this value state CRITICAL is returned 
    -j | --job      The backup job to search for in the database for the specified hostname
    --dbhost        Bacula database host
    --db            Bacula database name
    --dbuser        Bacula database user
    --dbpass        Bacula database password
