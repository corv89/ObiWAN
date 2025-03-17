import asyncdispatch
import os
import strutils # For parseInt
import "../../obiwan"

# Gemini asynchronous server
proc handleRequest(request: AsyncRequest) {.async.} =
  if request.url.path == "/auth":
    echo request.url.path
    if not request.hasCertificate():
      await request.respond(CertificateRequired, "CLIENT CERTIFICATE REQUIRED")
    elif not (request.isVerified() or request.isSelfSigned()):
      await request.respond(CertificateRequired, "CERTIFICATE NOT VALID")
    else:
      # Client certificate is valid
      var response = "# Certificate accepted\n\n"
      if request.certificate != nil:
        response.add("## Certificate Information\n\n")
        response.add("Certificate available\n")
        response.add("Verified: " & $request.isVerified & "\n")
        response.add("Self-signed: " & $request.isSelfSigned & "\n\n")
      response.add("Hello authenticated client!")
      await request.respond(Success, "text/gemini", response)
  else:
    await request.respond(Success, "text/gemini", "# Hello world\n\nThis is the ObiWAN Gemini server.\n\nTry visiting /auth to test client certificate authentication.")

var certFile = if paramCount() >= 1: paramStr(1) else: "cert.pem"
var keyFile = if paramCount() >= 2: paramStr(2) else: "privkey.pem"
var port = if paramCount() >= 3: parseInt(paramStr(3)) else: 1965
echo "Starting async server with certificates: ", certFile, ", ", keyFile
echo "Listening on port ", port, "..."
var server = newAsyncObiwanServer(certFile = certFile, keyFile = keyFile)
waitFor server.serve(port, handleRequest)
# Without IPv6 support:
#waitFor server.serve(Port(1965), handleRequest)
