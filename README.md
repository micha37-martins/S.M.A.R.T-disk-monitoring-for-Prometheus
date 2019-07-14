# S.M.A.R.T.-disk-monitoring-for-Prometheus text_collector

Prometheus `node_exporter` `text_collector` for S.M.A.R.T disk values

Following dashboards are designed for this exporter:

https://grafana.com/dashboards/10530
https://grafana.com/dashboards/10531

## Purpose
This text_collector is a customized version of the S.M.A.R.T. `text_collector` example from `node_exporter` github repo:
https://github.com/prometheus/node_exporter/tree/master/text_collector_examples

## Requirements
- Prometheus
- node_exporter
  - text_collector enabled for node_exporter
- Grafana >= 6.2.5
- smartmontools >= 7.0

## Set up
To enable text_collector set the following flag for `node_exporter`:
- `--collector.textfile.directory`

To get an up to date version of smartmontools it could be necessary to compile it:
https://www.smartmontools.org/wiki/Download#Installfromthesourcetarball

- check by executing `smartctl --version`

- make smartmon.sh executable

- save it under `/usr/local/bin/smartmon.sh`

To enable the text_collector on your system add the following as cronjob.
It will execute the script every five minutes and save the result to the `text_collector` directory.

Example for UBUNTU `crontab -e`:

`*/5 * * * * /usr/local/bin/smartmon.sh > /var/lib/node_exporter/textfile_collector/smart_metrics.prom`

## How to add specific S.M.A.R.T. attributes
If you are missing some attributes you can extend the text_collector.
Add the desired attributes to `smartmon_attrs` array in `smartmon.sh`.

You get a list of your disks privided attributes by executing:
`sudo 	smartctl -i -H /dev/<sdx>`
`sudo 	smartctl -A /dev/<sdx>`


