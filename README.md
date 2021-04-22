# fritz-dect
Read data from Fritz!Box using Fritz!DECT devices.

Working with:
* Fritz!Dect 200
* Fritz!Dect 210
* Fritz!Dect 100

Not tested, but should also work with:
* Fritz!Dect 301
* Fritz!Dect 500

## Getting started
Copy `dect.config.example` to `dect.config` and adjust configuration variables to your needs. Be sure to insert correct username and password and AINs.

To create entries every 30 seconds create crontab entries like this:
```
* *     * * *   root    /usr/local/bin/dect/dect-data-retrieval.sh
* *     * * *   root    sleep 30; /usr/local/bin/dect/dect-data-retrieval.sh
```

Since crontab can only trigger commands every minute lets just call it with a 30 seconds sleep time.

To create hourly, daily and monthly data we just copy from the last 30 seconds data into a hourly/daily/monthly file. Create crontab entries for creating:
```
1 *     * * *   root    /usr/local/bin/dect/dect-cron.sh -h
1 6     * * *   root    /usr/local/bin/dect/dect-cron.sh -d
1 6     1 * *   root    /usr/local/bin/dect/dect-cron.sh -m
```

## Thanks
Thanks to AVM for creating such amazing products. These scripts were created using their documentation.
