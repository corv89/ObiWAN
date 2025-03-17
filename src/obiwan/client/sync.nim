import os
import "../../obiwan"

# Gemini synchronous client
let
  url = if paramCount() >= 1: paramStr(1) else: "gemini://geminiprotocol.net/"
  certFile = if paramCount() >= 2: paramStr(2) else: ""
  keyFile = if paramCount() >= 3: paramStr(3) else: ""
try:
  echo "Creating client with mbedTLS..."
  let client = newObiwanClient(certFile=certFile, keyFile=keyFile)
  echo "Sending request to ", url
  let response = client.request(url)
  defer: client.close()

  echo "Status: " & $response.status
  echo "Meta: " & response.meta

  echo "Certificate info:"
  if response.certificate != nil:
    echo "  Certificate available"
    echo "  Is Verified: " & $response.isVerified
    echo "  Is Self-signed: " & $response.isSelfSigned
  else:
    echo "  No certificate available"

  echo "Response body:"
  echo response.body
except:
  echo "Error: ", getCurrentExceptionMsg()
