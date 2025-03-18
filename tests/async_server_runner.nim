## Async test server runner for ObiWAN
##
## This module runs an async test server for the test suite. It is launched as a separate
## process by the test suite.

import asyncdispatch

# The path is provided via the --path:src command line option

# Now import our package
import obiwan
import obiwan/common
import obiwan/server/async
import obiwan/debug

const
  TestPort = 1967 # Use non-standard port for testing
  TestCertFile = "tests/test_cert.pem"
  TestKeyFile = "tests/test_key.pem"

proc handleRequest(request: AsyncRequest): Future[void] {.async.} =
  debug("Received request: " & $request.url)

  # Check for client certificate
  if request.hasCertificate:
    debug("Client provided certificate")

  # URL handling tests
  let path = request.url.path

  # Handle different paths for different test cases
  if path == "/" or path == "":
    # Default response
    await request.respond(Success, "text/gemini", """
# Hello world

This is the ObiWAN Gemini async test server.

Try visiting /auth to test client certificate authentication.
""")
  elif path == "/auth":
    # Client certificate required
    if not request.hasCertificate:
      await request.respond(CertificateRequired, "Certificate required")
    else:
      await request.respond(Success, "text/gemini", """
# Authenticated

You have successfully authenticated with a client certificate.
""")
  else:
    # Not found response
    await request.respond(NotFound, "Resource not found")

proc main() {.async.} =
  # Create server with test certificate and key
  let server = newAsyncObiwanServer(
    certFile = TestCertFile,
    keyFile = TestKeyFile
  )

  # Start serving
  echo "Starting async test server on port ", TestPort
  await server.serve(TestPort, handleRequest)

when isMainModule:
  waitFor main()
