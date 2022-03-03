import logging
import teledonte_config

proc setup_logger*() =
  var L = newConsoleLogger(
    fmtStr="$levelname, [$time] ",
    levelThreshold=config.log_level,
  )
  addHandler(L)
