import os
import strutils # For parseInt
import "../../obiwan"

# Gemini synchronous server
proc handleRequest(request: Request) =
  echo "Request path: ", request.url.path
  if request.url.path == "/auth":
    if not request.hasCertificate():
      request.respond(CertificateRequired, "CLIENT CERTIFICATE REQUIRED")
    elif not (request.isVerified() or request.isSelfSigned()):
      request.respond(CertificateRequired, "CERTIFICATE NOT VALID")
    else:
      # Client certificate is valid
      var response = "# Certificate accepted\n\n"
      if request.certificate != nil:
        response.add("## Certificate Information\n\n")
        response.add("Certificate available\n")
        response.add("Verified: " & $request.isVerified & "\n")
        response.add("Self-signed: " & $request.isSelfSigned & "\n\n")
      response.add("Hello authenticated client!")
      request.respond(Success, "text/gemini", response)
  else:
    request.respond(Success, "text/gemini", "# Hello world\n\nThis is a the ObiWAN Gemini server.\n\nTry visiting /auth to test client certificate authentication.")

try:
  var certFile = if paramCount() >= 1: paramStr(1) else: "cert.pem"
  var keyFile = if paramCount() >= 2: paramStr(2) else: "privkey.pem"
  var port = if paramCount() >= 3: parseInt(paramStr(3)) else: 1965

  echo "Starting server with certificates: ", certFile, ", ", keyFile
  var server = newObiwanServer(certFile = certFile, keyFile = keyFile)
  echo "Server created successfully. Listening on port ", port, "..."

  # Change this line if you want to use IPv6
  server.serve(port, handleRequest)
except:
  echo "Error: ", getCurrentExceptionMsg()
