import logging
import telemasto_config

var L* = newConsoleLogger(fmtStr="$levelname, [$time] ", levelThreshold=config.log_level)
addHandler(L)
