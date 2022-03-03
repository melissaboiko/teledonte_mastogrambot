import std/strutils, std/strformat
import system/io, std/streams, std/json, std/marshal
import os, std/terminal, logging
import std/net, std/uri, std/httpclient

import telemasto_config

const API_PATH = "api/v1"

# opaque stuff we don't care about.
# client_id and client_secret are the important ones.
type Mastodon_app_token = object
    id*: string
    name*: string
    website*: string # can be nil
    redirect_uri*: string
    client_id*: string
    client_secret*: string
    vapid_key*: string

type Mastodon_oauth_token = object
    access_token*: string
    token_type*: string
    scope*: string # space-separated; we don't care
    created_at*: int # timestamp; we don't care

type Mastobot* = object
  user*: string
  instance*: string
  apiurl*: string
  client*: HttpClient
  app_token*: Mastodon_app_token
  oauth_token*: Mastodon_oauth_token


proc read_username(): string =
  let f = open(config.paths.mastodon_user)
  return strip(readAll(f))

proc get_usertuple(full_username: string): (string, string) =
  assert('@' in full_username)
  let pair = split(full_username, '@')[^2..^1]
  return(pair[0], pair[1])

proc read_app_token(): Mastodon_app_token =
  let path = config.paths.mastodon_app_token
  # stream won't raise a normal exception for this; this way's easier to catch.
  info("Will read app token JSON at ", path)
  if not fileExists(path):
    raise newException(IOError, &"No such file: {path}")

  let strm = newFileStream(path, fmRead)
  let j = parseJson(strm, path)
  return to(j, Mastodon_app_token)

proc read_oauth_token(): Mastodon_oauth_token=
  let path = config.paths.mastodon_oauth_token
  # stream won't raise a normal exception for this; this way's easier to catch.
  info("Will read oauth token JSON at ", path)
  if not fileExists(path):
    raise newException(IOError, &"No such file: {path}")

  let strm = newFileStream(path, fmRead)
  let j = parseJson(strm, path)
  return to(j, Mastodon_oauth_token)


proc write_app_token(token: Mastodon_app_token) =
  let path = config.paths.mastodon_app_token
  info("Will write new app token to ", path)
  debug("App token: ", token)
  let strm = newFileStream(path, fmWrite)
  store(strm, token)
  strm.close()

proc write_oauth_token(token: Mastodon_oauth_token) =
  let path = config.paths.mastodon_oauth_token
  info("Will write new oauth token to ", path)
  debug("Oauth token: ", token)
  let strm = newFileStream(path, fmWrite)
  store(strm, token)
  strm.close()

proc format_response_body(r: Response): string =
  if "application/json" in r.content_type():
    result=pretty(parseJson(r.body))
  else:
    result=r.body

proc mastoget(b: Mastobot, path: string, apiurl:bool =true): string =
  let baseurl = (if apiurl:  b.apiurl else: &"https://{b.instance}")
  debug("GET with headers: ", b.client.headers)
  let response = b.client.get(&"{baseurl}/{path}")
  let fb = format_response_body(response)

  if response.status[0] == '2':
    return fb
  else:
    raise(
      newException(
        HttpRequestError,
        &"HTTP {response.status}: {fb}"
    ))

proc mastopost_formdata(b: Mastobot, path: string,
                        data: MultipartData,
                        apiurl:bool=true,
                       ): Response =
    let baseurl = (if apiurl:  b.apiurl else: &"https://{b.instance}")
    let r = b.client.post(&"{baseurl}/{path}", multipart=data)
    if r.status[0] == '2':
      return r
    else:
      let fb = format_response_body(r)
      raise(
        newException(
          HttpRequestError,
          &"HTTP {r.status}: {fb}"
      ))

proc mastobot_registerapp(b: Mastobot): Mastodon_app_token =
  let data = newMultipartData({
    "client_name": "teledonte_bot",

    # display the authorization code to the user instead of
    # redirecting to a web page.
    "redirect_uris": "urn:ietf:wg:oauth:2.0:oob",
    "scopes": "read write",
    # "website": "",
  })
  let j = parseJson(mastopost_formdata(b, "apps", data).body)
  debug("Response:\n", pretty(j))
  result = to(j, Mastodon_app_token)
  debug("Tokenised:\n", result)

proc mastobot_getauthcode(b: Mastobot): string =
  let url = parseUri(&"https://{b.instance}/oauth") / "authorize" ? {
    "client_id": b.app_token.client_id,
    "scope": "read write",
    "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
    "response_type": "code"
  }
  var code = ""

  stdout.styledWriteLine({styleBright, styleUnderscore},fgRed,bgBlack, "\n\nAuthorisation needed nya!")
  while code == "":
    stdout.styledWriteLine(fgCyan, "pls to paste this in your browser:")
    echo(&"\n{$url}\n")
    stdout.styledWrite(fgCyan, "& then to copy the code here :3 ")
    stdout.styledWrite({styleBright,styleBlinkRapid}, fgRed, " > ")
    code = readLine(stdin)
    code = strip(code)
    if code == "":
      stdout.styledWriteLine(fgRed, "\ncant read this code >:(\n")
  return code

proc mastobot_get_oauthtoken(b: Mastobot, authcode: string): Mastodon_oauth_token =
  let data = newMultipartData({
    "client_id": b.app_token.client_id,
    "client_secret": b.app_token.client_secret,
    "redirect_uri": "urn:ietf:wg:oauth:2.0:oob",
    "grant_type": "authorization_code",
    "code": authcode,
    "scope": "read write",
  })
  debug("Will try oauthtoken with data: ", data)

  let j = parseJson(mastopost_formdata(b, "oauth/token", data, apiurl=false).body)
  debug("Response:\n", pretty(j))
  return to(j, Mastodon_oauth_token)


proc newMastobot*(): Mastobot =
  let (user, instance) = get_usertuple(read_username())
  let apiurl: string = &"https://{instance}/{API_PATH}"

  let client = newHttpClient(sslContext=newContext(verifyMode=CVerifyPeer))

  var mastobot = Mastobot(user: user,
                         instance: instance,
                         apiurl: apiurl,
                         client: client)

  let test = mastoget(mastobot, "instance")
  info(&"yay, Mastodon instance {instance} is reachable nya")
  debug(&"instance data:\n{test}")

  try:
    let app_token = read_app_token()
    info("Read Mastodon app token from file nya")
    mastobot.app_token = app_token

  except IOError:
    warn(&"Could not find a mastodon app token: {getCurrentExceptionMsg()}, nyan!")
    info("Will registre new app nya")
    let app_token = mastobot_registerapp(mastobot)
    info("Got it, nyow will save to file nya")
    debug("Token:", app_token)
    write_app_token(app_token)
    mastobot.app_token = app_token

  try:
    let oauth_token = read_oauth_token()
    info("Read Mastodon oauth token from file nya")
    mastobot.oauth_token = oauth_token

  except IOError:
    warn(&"Could not find a mastodon oauth token: {getCurrentExceptionMsg()}, nyan!")
    info("Will ask permission nya")
    let authcode = mastobot_getauthcode(mastobot)
    info("Got authcode! nyow will get oauth token w/ it nya")
    let oauth_token = mastobot_get_oauthtoken(mastobot, authcode)
    info("Yay it works!! will save to file nya")
    write_oauth_token(oauth_token)
    mastobot.oauth_token = oauth_token

  info("Testing Mastodon tokens nya")
  mastobot.client.headers = newHttpHeaders({
    "Authorization": "Bearer " & mastobot.oauth_token.access_token
  })
  debug("Verify credentials: ", mastoget(mastobot, "accounts/verify_credentials"))
  debug("Some notifications: ", mastoget(mastobot, "notifications?limit=3"))
  return mastobot
