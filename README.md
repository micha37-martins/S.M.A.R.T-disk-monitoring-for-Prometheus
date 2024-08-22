![Tag](https://img.shields.io/github/v/tag/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus)

![Coverage](https://img.shields.io/badge/Coverage-65.2%25-brightgreen)

![Language](https://img.shields.io/github/languages/top/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus)

![Downloads](https://img.shields.io/github/downloads/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus/total)

![License](https://img.shields.io/github/license/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus)

![Forks](https://img.shields.io/github/forks/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus)

![Stars](https://img.shields.io/github/stars/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus)

![Last Commit](https://img.shields.io/github/last-commit/micha37-martins/S.M.A.R.T-disk-monitoring-for-Prometheus)

# S.M.A.R.T.-disk-monitoring-for-Prometheus text_collector

Prometheus `node_exporter` `text_collector` for S.M.A.R.T disk values

Following dashboards are designed for this exporter:

https://grafana.com/dashboards/10530

https://grafana.com/dashboards/10531

## Purpose
This text_collector is a customized version of the S.M.A.R.T. `text_collector`
example from `node_exporter` github repo:
https://github.com/prometheus/node_exporter/tree/master/text_collector_examples

This bash script uses `smartctl` to get S.M.A.R.T. values. It is designed to
work with SATA and NVME disks. It should also work with SCSI disks but is not
tested.

## Requirements
- Prometheus
- node_exporter
  - text_collector enabled for node_exporter
- Grafana >= 10
- smartmontools >= 7
- jq

## Set up
To enable text_collector set the following flag for `node_exporter`:
- `--collector.textfile.directory`
run command with `/var/lib/node_exporter/textfile_collector`

Install [smartmontools](https://www.smartmontools.org/)

For UBUNTU: `sudo apt-get install smartmontools`

To enable the text_collector on your system add the following as cronjob.
It will execute the script every five minutes and save the result to the `text_collector` directory.

Example for UBUNTU `sudo crontab -e`:

`*/5 * * * * /usr/local/bin/smartmon.sh > /var/lib/node_exporter/textfile_collector/smart_metrics.prom`

# TODO: adapt to new script
## How to add specific S.M.A.R.T. attributes
If you are missing some attributes you can extend the text_collector.
Add the desired attributes to `smartmon_attrs` array in `smartmon.sh`.

You get a list of your disks privided attributes by executing:
`sudo 	smartctl -i -H /dev/<sdx>`
`sudo 	smartctl -A /dev/<sdx>`

## Running Locally
If you want to test the exporter locally. For example on a laptop you can move
the exporter to the following directory and run it.
```sh
# execute collector
sudo sh -c 'smartmon.sh > /var/lib/node_exporter/textfile_collector/smart_metrics.prom' 

# let node-exporter run
/usr/bin/prometheus-node-exporter --collector.textfile.directory /var/lib/node_exporter/textfile_collector/
```

## Troubleshooting
To get an up to date version of smartmontools it could be necessary to compile it:
https://www.smartmontools.org/wiki/Download#Installfromthesourcetarball

- check by executing `smartctl --version`

- make smartmon.sh executable

- save it under `/usr/local/bin/smartmon.sh`

- make sure `/var/lib/node_exporter/textfile_collector/` exists
  - `mkdir -p /var/lib/node_exporter/textfile_collector/`


## Tests
# TODO: tests install bats (bats-core):
[bats-tutorial](https://bats-core.readthedocs.io/en/stable/tutorial.html)

## Coverage
´´´sh
run_coverage.sh
```

### Manual Coverage
kcov --bash-dont-parse-binary-dir \
     --include-path=. \
     /var/tmp/coverage \
     bats -t test/test_smartmon.bats

## TODO
- Write docs
- docker
- systemd instead of cron
