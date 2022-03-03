import std/json, system/io, std/streams, logging
const CONFIG_PATH = "config.json"

type Paths = object
  telegram_api_key*: string
  mastodon_token*: string
  teletootsdb*: string

type Config = object
  log_level*: Level
  paths*: Paths
  poll_interval*: int

proc read_config(path=CONFIG_PATH): Config =
  let strm = newFileStream(path, fmRead)
  let node = parseJson(strm, path)
  return to(node, Config)

let config* = read_config()
