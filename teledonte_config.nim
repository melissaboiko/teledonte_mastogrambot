import std/json, system/io, std/streams, logging
const CONFIG_PATH = "config.json"

type Paths = object
  telegram_api_key*: string
  teletootsdb*: string
  mastodon_user*: string
  mastodon_app_token*: string
  mastodon_oauth_token*: string

type Config = object
  log_level*: Level
  poll_interval*: int
  paths*: Paths

proc read_config(path=CONFIG_PATH): Config =
  let strm = newFileStream(path, fmRead)
  let node = parseJson(strm, path)
  return to(node, Config)

let config* = read_config()
