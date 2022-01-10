# fritz-dect
Read data from Fritz!Box using Fritz!DECT devices.

Working with:
* Fritz!Dect 100
* Fritz!Dect 200 (Readout: temperature, state, current energy consumption, accumulated energy consumption)
* Fritz!Dect 210 (Readout: temperature, state, current energy consumption, accumulated energy consumption)
* Fritz!Dect 301 (Readout: temperature, tsoll, battery, window open active, boost active, window open time, boost active time)
* Fritz!Dect 440 (Readout: temperature, battery)
* Han-Fun Blinds (e.g. RolloTron Dect 1213 --> readout: level)

Not tested, but should also work with:
* Fritz!Dect 500

## Getting started
Copy `dect.config.example` to `dect.config` and adjust configuration variables to your needs. Be sure to insert correct username and password and AINs. Copy the configuration file to a location of your desire and adjust the header in `dect-data-retrieval.sh` and `dect-cron.sh` to match that directory.

To create entries every 30 seconds create crontab entries like this:
```
* *     * * *   user    /usr/local/bin/dect/dect-data-retrieval.sh
* *     * * *   user    sleep 30; /usr/local/bin/dect/dect-data-retrieval.sh
```

Since crontab can only trigger commands every minute lets just call it with a 30 seconds sleep time.

To create hourly, daily and monthly data we just copy from the last 30 seconds data into a hourly/daily/monthly file. Create crontab entries for creating:
```
1 *     * * *   user    /usr/local/bin/dect/dect-cron.sh -h
1 6     * * *   user    /usr/local/bin/dect/dect-cron.sh -d
1 6     1 * *   user    /usr/local/bin/dect/dect-cron.sh -m
```

Important: Please adjust the user to a user avaiable on your system with rights to execute the scripts

## Testing ##
To test your configuration you can execute `.\dect-data-retrieval.sh debug` and you will see some output.

## Create graphs from data ##
I have created simple power graphs to view the extracted data. Please have a look at [power-graphs](https://github.com/micha2el/power-graphs).

## Thanks
Thanks to AVM for creating such amazing products. These scripts were created using their documentation.
