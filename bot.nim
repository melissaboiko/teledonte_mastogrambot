import telebot, asyncdispatch, logging, options, std/strutils, std/strformat, std/json, std/os, system/io, std/streams
import telemasto_config
import telegram_bot

# echo(config.paths.telegram_api_key)
echo(config.poll_interval)

var L = newConsoleLogger(fmtStr="$levelname, [$time] ", levelThreshold=config.log_level)
addHandler(L)

type TeledonteBot = ref object
  telebot: Telebot
  # mastobot:
  teletootsdb: JsonNode
  teletoots_path: string

proc save_teletootsdb(this: TeledonteBot) =
  let f = open(this.teletoots_path, fmWrite)
  f.write($this.teletootsdb)
  f.close()

proc init_teletootsdb(this: TeledonteBot) =
  let path = this.teletoots_path
  if fileExists(path):
    info("reading JSON file ", path)
    let strm = newFileStream(path, fmRead)
    this.teletootsdb = parseJson(strm, path)
    strm.close()
  else:
    info("found no JSON file ", path)
    this.teletootsdb = %* {"telegrams": {}}
    this.save_teletootsdb()


# proc init_mastobot(


proc toot(this: TeledonteBot, req: Message) =
  warn("Not implemented yet nya: toot: ", req)
proc deltoot(this: TeledonteBot, req: Message) =
  warn("Not implemented yet nya: toot: ", req)
proc retoot(this: TeledonteBot, req: Message) =
  warn("Not implemented yet nya: toot: ", req)

proc reply(b: Telebot,
           message: Message,
           replytext: string,
           parseMode="Markdown") =
  asyncCheck b.sendmessage(
    message.chat.id,
    replytext,
    disableNotification=true,
    replyToMessageId=message.messageId,
    parseMode="Markdown",
  )


proc process_request(this: TeledonteBot, req: Message): bool =
  info("Got request nya: ", req)
  let tb = this.telebot

  if not req.replyToMessage.isSome:
    warn("Request without nyattached message!")
    this.telebot.reply(req, "no nyattached message, dont kno what to do nya")
    return(false)

  let cmd = strip(req.text.get.replace("@" & tb.username, ""))
  case cmd
  of "post":
    this.telebot.reply(req, "ok i will post it to masto nya")
    this.toot(req)
  of "delete":
    this.telebot.reply(req, "ok i will delyete it in masto nya")
    this.deltoot(req)
  of "update":
    this.telebot.reply(req, "ok i will delyete & repost it in masto nya")
    this.retoot(req)
  else:
    warn("Unknow request nya!: ", cmd)
    this.telebot.reply(req, &"i dont kno how 2 `'{cmd}'` mew")
    return(false)

  return(true)


# makes a lambda for the Telegram update handler that dynamically points to the
# parent TeledonteBot object.
proc closure_telegramUpdateHandler(parent: TeledonteBot):
  (proc(b: Telebot, u: Update): Future[bool] {.async,gcsafe.}) =

  return proc(b: Telebot, u: Update): Future[bool] {.async,gcsafe.} =
    if not u.message.isSome:
      # return true will make Telegram bot stop process other callbacks
      return true
    var response = u.message.get
    if response.text.isSome:
      if response.entities.isSome:
        for e in response.entities.get:
          # e.user is not for this
          if e.kind == "mention" and ("@" & b.username) in response.text.get:
            discard parent.process_request(response)
            parent.save_teletootsdb()


proc install_telegramUpdateHandler(this: TeledonteBot) =
  let callback = this.closure_telegramUpdateHandler()
  this.telebot.onUpdate(callback)


proc poll(this: TeledonteBot, timeout=config.poll_interval) =
  this.telebot.poll(timeout=timeout)


proc newTeledonteBot(t_api_key_path=config.paths.telegram_api_key,
                     teletoots_path=config.paths.teletootsdb,
                    ): TeledonteBot =
  let f = open(t_api_key_path)
  let t_api_key = strip(readAll(f))
  let telebot = newTeleBot(t_apikey)
  # mastobot =
  result=TeledonteBot(
    telebot: telebot,
    teletoots_path: teletoots_path,
  )
  result.init_teletootsdb()
  result.install_telegramUpdateHandler()

let tdBot = newTeledonteBot()
tdBot.poll()
