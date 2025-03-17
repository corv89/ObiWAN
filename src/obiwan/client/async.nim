import asyncdispatch
import os
import strutils

import "../../obiwan"

# Gemini asynchronous client
proc main() {.async.} =
  let
    url = if paramCount() >= 1: paramStr(1) else: "gemini://geminiprotocol.net/"
    certFile = if paramCount() >= 2: paramStr(2) else: ""
    keyFile = if paramCount() >= 3: paramStr(3) else: ""
  try:
    let client = newAsyncObiwanClient(certFile=certFile, keyFile=keyFile)
    let response = await client.request(url)
    defer: client.close()

    echo "Status: " & $response.status
    echo "Meta: " & response.meta
    echo "Server certificate:"
    if response.certificate != nil:
      echo "  Certificate available"
      echo "  Is Verified: " & $response.isVerified
      echo "  Is Self-signed: " & $response.isSelfSigned
    else:
      echo "  No certificate available"

    echo "body: " & await response.body
  except:
    echo getCurrentExceptionMsg()

waitFor main()
