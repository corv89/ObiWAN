## ObiWAN Gemini protocol library

# Standard library imports
import asyncdispatch
import asyncnet
import random
import nimcrypto
import strutils
import streams
import net
import posix
import os # For fileExists

# URL handling
import obiwan/url

# Core components
import obiwan/common
import obiwan/debug

# TLS implementation
import obiwan/tls/mbedtls as mbedtls
import obiwan/tls/socket as tlsSocket
import obiwan/tls/async_socket as tlsAsyncSocket

# Note: We've moved the platform-specific key file parsing directly into the
# loadIdentityFile function for better clarity and to avoid pointer manipulation issues.

# Concrete type aliases for TLS implementation
type
  ## Certificate and error types
  X509Certificate* = tlsSocket.X509Certificate
    ## X.509 certificate type for TLS encryption and authentication.

  MbedtlsError* = tlsSocket.MbedtlsError
    ## mbedTLS-specific error type.

  ## Socket implementation types
  MbedtlsSocket* = tlsSocket.MbedtlsSocket
    ## Synchronous TLS socket implementation using mbedTLS.

  MbedtlsSocketObj* = tlsSocket.MbedtlsSocketObj
    ## Concrete object type for synchronous TLS sockets.

  MbedtlsAsyncSocket* = tlsAsyncSocket.MbedtlsAsyncSocket
    ## Asynchronous TLS socket implementation using mbedTLS.

  MbedtlsAsyncSocketObj* = tlsAsyncSocket.MbedtlsAsyncSocketObj
    ## Concrete object type for asynchronous TLS sockets.

  ## TLS context types
  MbedtlsSslContext* = tlsSocket.MbedtlsSslContext
    ## Concrete SSL/TLS context implementation using mbedTLS.

  SslContext* = tlsSocket.BaseSslContext
    ## Base SSL/TLS context type for both synchronous and asynchronous operations.

  ## Client types
  ObiwanClient* = ObiwanClientBase[MbedtlsSocket]
    ## Synchronous Gemini protocol client.
    ## Use this type for blocking, synchronous operations.

  AsyncObiwanClient* = ObiwanClientBase[MbedtlsAsyncSocket]
    ## Asynchronous Gemini protocol client.
    ## Use this type for non-blocking, asynchronous operations.

  ## Response types
  Response* = ResponseBase[ObiwanClient]
    ## Synchronous response from a Gemini server.
    ## Contains status, meta information, and certificate details.

  AsyncResponse* = ResponseBase[AsyncObiwanClient]
    ## Asynchronous response from a Gemini server.
    ## Contains status, meta information, and certificate details.

  ## Server types
  ObiwanServer* = ObiwanServerBase[MbedtlsSocket]
    ## Synchronous Gemini protocol server.
    ## Use this type for blocking, synchronous server implementations.

  AsyncObiwanServer* = ObiwanServerBase[MbedtlsAsyncSocket]
    ## Asynchronous Gemini protocol server.
    ## Use this type for non-blocking, asynchronous server implementations.

  ## Request types
  Request* = RequestBase[MbedtlsSocket]
    ## Synchronous request received by a Gemini server.
    ## Contains URL, client certificate, and verification information.

  AsyncRequest* = RequestBase[MbedtlsAsyncSocket]
    ## Asynchronous request received by a Gemini server.
    ## Contains URL, client certificate, and verification information.

# Export public types and functions
export common
export debug
# Export certificate handling functions
export tlsSocket.`$`
export tlsSocket.commonName
export tlsSocket.fingerprint
export tlsAsyncSocket.newMbedtlsAsyncSocket
export tlsSocket.handshakeAsClient, tlsSocket.handshakeAsServer
export tlsAsyncSocket.handshakeAsClient, tlsAsyncSocket.handshakeAsServer
export debug.debug, debug.debugf, debug.withDebug, debug.debugEnabled

# Export config module
import obiwan/config
export config

# Certificate handling is available through the tlsSocket module

# Client API
proc loadIdentityFile*(client: ObiwanClient | AsyncObiwanClient; certFile,
    keyFile: string): bool =
  ## Loads a client certificate and private key from PEM files for client authentication.
  ##
  ## This allows the client to offer a certificate to the server when connecting, which
  ## is used for client authentication in the Gemini protocol. The server may require
  ## a certificate for certain resources (indicated by status codes 60-62).
  ##
  ## Parameters:
  ##   client: The ObiwanClient or AsyncObiwanClient instance
  ##   certFile: Path to the certificate file in PEM format
  ##   keyFile: Path to the private key file in PEM format
  ##
  ## Returns:
  ##   `true` if the certificate and key were loaded successfully, `false` otherwise
  ##
  ## Raises:
  ##   No exceptions are raised; errors are reported via the return value.
  # Use the context directly as MbedtlsSslContext
  let ctx = cast[MbedtlsSslContext](client.sslContext)

  debug("Loading client certificate from: " & certFile)

  # Make sure the certificates exist
  if not fileExists(certFile):
    error("Certificate file not found: " & certFile)
    return false

  if not fileExists(keyFile):
    error("Key file not found: " & keyFile)
    return false

  # Initialize SSL config (should be done already, but let's make sure)
  debug("Making sure SSL config is properly initialized")

  # Configure auth mode first - in mbedTLS this needs to be done before cert setup
  debug("Setting auth mode to MBEDTLS_SSL_VERIFY_OPTIONAL")
  mbedtls.mbedtls_ssl_conf_authmode(addr ctx.config,
      mbedtls.MBEDTLS_SSL_VERIFY_OPTIONAL)

  # Parse the certificate - direct approach, avoiding pointer manipulation
  debug("Parsing certificate file: " & certFile)
  let ret1 = mbedtls.mbedtls_x509_crt_parse_file(addr ctx.cert, certFile)
  if ret1 != 0:
    # Get a more detailed error message
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret1, cast[cstring](addr errorStr[0]), 100)
    error("Failed to parse certificate file: " & errorStr & " (code: " & $ret1 & ")")
    return false

  debug("Certificate parsed successfully")

  # Parse the key - direct approach
  debug("Loading private key from: " & keyFile)

  let ret2 =
    mbedtls.mbedtls_pk_parse_keyfile(
      addr ctx.key, keyFile, nil,
      mbedtls.mbedtls_ctr_drbg_random, addr ctx.ctr_drbg)

  if ret2 != 0:
    # Get a more detailed error message
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret2, cast[cstring](addr errorStr[0]), 100)
    error("Failed to parse key file: " & errorStr & " (code: " & $ret2 & ")")
    return false

  debug("Private key parsed successfully")

  # Configure certificate in SSL context
  debug("Setting up client certificate for SSL/TLS with mbedtls_ssl_conf_own_cert")
  let ret3 = mbedtls.mbedtls_ssl_conf_own_cert(addr ctx.config,
                                          addr ctx.cert,
                                          addr ctx.key)
  if ret3 != 0:
    # Get a more detailed error message
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret3, cast[cstring](addr errorStr[0]), 100)
    error("Failed to configure client certificate: " & errorStr & " (code: " &
        $ret3 & ")")
    return false

  # Double-check client certificate configuration
  debug("Client certificate configuration complete")
  debug("Client certificate should now be ready for TLS handshake")
  return true


proc newObiwanClient*(maxRedirects = 5; certFile = "";
    keyFile = ""): ObiwanClient =
  ## Creates a new synchronous Gemini protocol client.
  ##
  ## This function creates a synchronous client for making Gemini protocol requests.
  ## The client handles TLS connections with proper certificate verification for the
  ## Gemini protocol's security model, which includes support for self-signed certificates.
  ##
  ## Parameters:
  ##   maxRedirects: Maximum number of redirects to follow automatically (default: 5)
  ##   certFile: Optional path to client certificate file in PEM format (for client authentication)
  ##   keyFile: Optional path to client private key file in PEM format (for client authentication)
  ##
  ## Returns:
  ##   A new ObiwanClient instance ready for making requests
  ##
  ## Raises:
  ##   ObiwanError: If certificate files are specified but cannot be loaded
  ##
  ## Example:
  ##   ```nim
  ##   let client = newObiwanClient()
  ##   let response = client.request("gemini://example.com/")
  ##   if response.status == Status.Success:
  ##     let content = response.body()
  ##     echo content
  ##   ```
  result = ObiwanClient(maxRedirects: maxRedirects)
  result.bodyStreamVariant = (isFutureStream: false)
  result.bodyStreamSync = newStringStream()

  # Create TLS context
  var actualContext = tlsSocket.newContext()
  # Store concrete context directly
  result.sslContext = actualContext

  # Configure for client mode
  discard mbedtls.mbedtls_ssl_config_defaults(
    addr actualContext.config,
    mbedtls.MBEDTLS_SSL_IS_CLIENT,
    mbedtls.MBEDTLS_SSL_TRANSPORT_STREAM,
    mbedtls.MBEDTLS_SSL_PRESET_DEFAULT)

  # Set custom verify to allow self-signed certificates
  tlsSocket.setCustomVerify(actualContext)

  # For Gemini, set auth mode to none to skip certificate validation
  # This allows connecting to servers with self-signed certificates, which are common in Gemini
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config,
      mbedtls.MBEDTLS_SSL_VERIFY_NONE)

  # Load client certificate if provided
  if certFile != "" or keyFile != "":
    # Both must be provided or neither
    if certFile == "":
      raise newException(ObiwanError, "Key file provided without certificate file")
    if keyFile == "":
      raise newException(ObiwanError, "Certificate file provided without key file")

    debug("Loading client identity from certificate: " & certFile &
        " and key: " & keyFile)
    if not result.loadIdentityFile(certFile, keyFile):
      error("Failed to load client certificate files")
      raise newException(ObiwanError, "Failed to load client certificate files")

proc newAsyncObiwanClient*(maxRedirects = 5; certFile = "";
    keyFile = ""): AsyncObiwanClient =
  ## Creates a new asynchronous Gemini protocol client.
  ##
  ## This function creates an asynchronous client for making non-blocking Gemini protocol
  ## requests. The client handles TLS connections with proper certificate verification for
  ## the Gemini protocol's security model, which includes support for self-signed certificates.
  ##
  ## Parameters:
  ##   maxRedirects: Maximum number of redirects to follow automatically (default: 5)
  ##   certFile: Optional path to client certificate file in PEM format (for client authentication)
  ##   keyFile: Optional path to client private key file in PEM format (for client authentication)
  ##
  ## Returns:
  ##   A new AsyncObiwanClient instance ready for making async requests
  ##
  ## Raises:
  ##   ObiwanError: If certificate files are specified but cannot be loaded
  ##
  ## Example:
  ##   ```nim
  ##   proc main() {.async.} =
  ##     let client = newAsyncObiwanClient()
  ##     let response = await client.request("gemini://example.com/")
  ##     if response.status == Status.Success:
  ##       let content = await response.body()
  ##       echo content
  ##
  ##   waitFor main()
  ##   ```
  result = AsyncObiwanClient(maxRedirects: maxRedirects)
  result.bodyStreamVariant = (isFutureStream: true)
  result.bodyStreamAsync = newFutureStream[string]("newAsyncObiwanClient")

  # Create TLS context
  var actualContext = tlsSocket.newContext()
  # Store concrete context directly
  result.sslContext = actualContext

  # Configure for client mode
  discard mbedtls.mbedtls_ssl_config_defaults(
    addr actualContext.config,
    mbedtls.MBEDTLS_SSL_IS_CLIENT,
    mbedtls.MBEDTLS_SSL_TRANSPORT_STREAM,
    mbedtls.MBEDTLS_SSL_PRESET_DEFAULT)

  # Set custom verify to allow self-signed certificates
  tlsSocket.setCustomVerify(actualContext)

  # For Gemini, set auth mode to none to skip certificate validation
  # This allows connecting to servers with self-signed certificates, which are common in Gemini
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config,
      mbedtls.MBEDTLS_SSL_VERIFY_NONE)

  # Load client certificate if provided
  if certFile != "" or keyFile != "":
    # Both must be provided or neither
    if certFile == "":
      raise newException(ObiwanError, "Key file provided without certificate file")
    if keyFile == "":
      raise newException(ObiwanError, "Certificate file provided without key file")

    debug("Loading client identity from certificate: " & certFile &
        " and key: " & keyFile)
    if not result.loadIdentityFile(certFile, keyFile):
      error("Failed to load client certificate files")
      raise newException(ObiwanError, "Failed to load client certificate files")

proc loadUrl(client: ObiwanClient | AsyncObiwanClient; url: string): Future[
    Response | AsyncResponse] {.multisync.} =
  ## Internal helper function to load a URL
  let webbyUrl = parseUrl(url)
  let port = geminiPort(webbyUrl)
  if not validateGeminiUrl(webbyUrl):
    raise newException(ObiwanError, url & ": scheme not supported")

  # Use the context directly as MbedtlsSslContext
  let ctx = MbedtlsSslContext(client.sslContext)

  # Remove brackets from IPv6 addresses for socket connections
  let hostname = unbracketed(webbyUrl.hostname)

  when client is AsyncObiwanClient:
    result = AsyncResponse(client: client)
    client.socket = await tlsAsyncSocket.dial(hostname, port)
    await tlsAsyncSocket.wrapConnectedSocket(ctx, client.socket,
        tlsAsyncSocket.handshakeAsClient, hostname)
    # send data now to force TLS handshake to complete
    await client.socket.send(url & "\r\n")
  else:
    result = Response(client: client)
    client.socket = tlsSocket.dial(hostname, port)
    tlsSocket.wrapConnectedSocket(ctx, client.socket,
        tlsSocket.handshakeAsClient, hostname)
    # send data now to force TLS handshake to complete
    discard client.socket.send(url & "\r\n")

  # Get peer certificate
  let sslCtx = client.socket.getSslHandle()
  result.certificate = mbedtls.mbedtls_ssl_get_peer_cert(sslCtx)
  result.verification = mbedtls.mbedtls_ssl_get_verify_result(sslCtx).int

  let line = await client.socket.recvLine()
  if line.len < 3 or line[2] != ' ':
    raise newException(ObiwanError, "unexpected response format: \"" & line & "\"")
  result.status = toStatus(parseInt(line[0..1]))
  result.meta = line[3..^1]

  if result.status.int >= 30:
    client.socket.close()

proc request*(client: ObiwanClient | AsyncObiwanClient; url: string): Future[
    Response | AsyncResponse] {.multisync.} =
  ## Makes a Gemini protocol request to the specified URL and returns the response.
  ##
  ## This function handles the entire request process, including:
  ## - Establishing TLS connection to the server
  ## - Sending the URL request
  ## - Parsing the server's response status and meta information
  ## - Obtaining the server's certificate and verification status
  ## - Automatically following redirects up to client.maxRedirects
  ##
  ## The connection remains open if the request was successful (Status.Success),
  ## allowing the body content to be retrieved separately using the response.body() method.
  ## For other status codes, the connection is closed automatically.
  ##
  ## Parameters:
  ##   client: The ObiwanClient or AsyncObiwanClient to use for the request
  ##   url: The Gemini URL to request (must use gemini:// scheme)
  ##
  ## Returns:
  ##   A Response or AsyncResponse object containing status, meta, and certificate information
  ##
  ## Raises:
  ##   ObiwanError: For network errors, malformed responses, invalid URLs, or too many redirects
  ##
  ## Example:
  ##   ```nim
  ##   # Synchronous example
  ##   let client = newObiwanClient()
  ##   let response = client.request("gemini://example.com/")
  ##
  ##   # Asynchronous example
  ##   let client = newAsyncObiwanClient()
  ##   let response = await client.request("gemini://example.com/")
  ##   ```
  var url = url
  result = await client.loadUrl(url)
  for i in 1..client.maxRedirects:
    if result.status == Status.Redirect or result.status == Status.TempRedirect:
      let baseUrl = parseUrl(url)
      let targetUrl = parseUrl(result.meta)
      url = $combineUrl(baseUrl, targetUrl)
      result = await client.loadUrl(url)
    else:
      return
  client.socket.close()
  raise newException(ObiwanError, "too many redirects")

proc body*(response: Response | AsyncResponse): Future[string] {.multisync.} =
  ## Retrieves the body content associated with a successful response.
  ##
  ## This function reads the response body content from the server and returns it as a string.
  ## The connection to the server is automatically closed once the entire body has been retrieved.
  ## This should only be called on responses with Status.Success (20), as other status codes
  ## won't have a body to retrieve.
  ##
  ## Parameters:
  ##   response: The Response or AsyncResponse from a previous request call
  ##
  ## Returns:
  ##   The complete body content as a string
  ##
  ## Raises:
  ##   Various network-related exceptions may be raised during body retrieval
  ##
  ## Note:
  ##   - For synchronous clients, this blocks until the entire body is received
  ##   - For asynchronous clients, this returns a Future that completes when the body is fully received
  ##
  ## Example:
  ##   ```nim
  ##   # Synchronous example
  ##   let response = client.request("gemini://example.com/")
  ##   if response.status == Status.Success:
  ##     let content = response.body()
  ##     echo content
  ##
  ##   # Asynchronous example
  ##   let response = await client.request("gemini://example.com/")
  ##   if response.status == Status.Success:
  ##     let content = await response.body()
  ##     echo content
  ##   ```
  let client = response.client

  when response is AsyncResponse:
    # Async path
    while not tlsAsyncSocket.isClosed(client.socket):
      let data = await client.socket.recv(net.BufferSize)
      if data == "":
        client.socket.close()
        break # We've been disconnected.
      await client.bodyStreamAsync.write(data)
    client.bodyStreamAsync.complete()
    return await client.bodyStreamAsync.readAll()
  else:
    # Sync path
    var buffer = newString(net.BufferSize)
    while not tlsSocket.isClosed2(client.socket):
      let bytesRead = client.socket.recv(addr buffer[0], buffer.len)
      if bytesRead <= 0:
        client.socket.close()
        break # We've been disconnected.
      let data = buffer[0..<bytesRead]
      client.bodyStreamSync.write(data)
    client.bodyStreamSync.setPosition(0)
    return client.bodyStreamSync.readAll()

proc close*(client: ObiwanClient | AsyncObiwanClient) =
  ## Manually closes the client's connection to the server.
  ##
  ## This function explicitly closes the TLS socket connection to the server.
  ## Normally, this is handled automatically by the body() method, but you can
  ## use this method to close the connection early or if you don't need to
  ## retrieve the body content.
  ##
  ## Parameters:
  ##   client: The ObiwanClient or AsyncObiwanClient whose connection to close
  ##
  ## Example:
  ##   ```nim
  ##   let client = newObiwanClient()
  ##   let response = client.request("gemini://example.com/")
  ##   # Close without reading the body
  ##   client.close()
  ##   ```
  if not client.socket.isNil():
    client.socket.close()

# Server API
proc respond*(req: Request | AsyncRequest; status: Status; meta: string;
    body: string = "") {.multisync.} =
  ## Sends a response to a client according to the Gemini protocol specification.
  ##
  ## This function constructs and sends a properly formatted Gemini response, consisting of:
  ## - A status code (from the Status enum)
  ## - A meta string (whose meaning depends on the status code)
  ## - An optional body (only sent for Status.Success responses)
  ##
  ## The meta string's interpretation depends on the status code category:
  ## - 1x (Input): A prompt for user input
  ## - 2x (Success): A MIME type for the content (e.g., "text/gemini")
  ## - 3x (Redirect): A target URL
  ## - 4x/5x (Error): An error message
  ## - 6x (Client Certificate): Information about certificate requirements
  ##
  ## Parameters:
  ##   req: The Request or AsyncRequest to respond to
  ##   status: The status code to send (see Status enum)
  ##   meta: The meta information string (max 1024 characters)
  ##   body: Optional body content (only sent for Status.Success)
  ##
  ## Raises:
  ##   AssertionDefect: If meta exceeds 1024 characters
  ##   Various exceptions may be caught internally and result in an error response
  ##
  ## Example:
  ##   ```nim
  ##   # Success response with content
  ##   req.respond(Status.Success, "text/gemini", "# Welcome to my Gemini server\n\nHello world!")
  ##
  ##   # Not found error
  ##   req.respond(Status.NotFound, "Resource not available")
  ##
  ##   # Redirect
  ##   req.respond(Status.Redirect, "gemini://example.com/new-location")
  ##   ```
  try:
    assert meta.len <= 1024
    when req is AsyncRequest:
      await req.client.send($status.int & ' ' & meta & "\r\n")
      if status == Status.Success:
        await req.client.send(body)
    else:
      discard req.client.send($status.int & ' ' & meta & "\r\n")
      if status == Status.Success:
        discard req.client.send(body)
  except CatchableError:
    echo getCurrentExceptionMsg()
    when req is AsyncRequest:
      await req.client.send($Status.Error.int & " INTERNAL ERROR\r\n")
    else:
      discard req.client.send($Status.Error.int & " INTERNAL ERROR\r\n")

# Method to accept connections for synchronous server
proc serve*(server: ObiwanServer; port: int; callback: proc(request: Request);
    address = "") =
  ## Starts a synchronous Gemini protocol server on the specified port.
  ##
  ## This function starts a server that listens for incoming Gemini protocol requests.
  ## For each connection, it handles the TLS handshake, reads the request, and calls
  ## the provided callback function with a Request object. The callback is responsible
  ## for calling respond() to send a response.
  ##
  ## Note that this is a blocking operation that runs indefinitely until the process
  ## is terminated.
  ##
  ## Parameters:
  ##   server: The ObiwanServer instance created with newObiwanServer()
  ##   port: The port to listen on (standard Gemini port is 1965)
  ##   callback: A procedure to call for each received request
  ##   address: Optional IP address to bind to (default: "0.0.0.0"). Use "::" for IPv6 with
  ##            possible dual-stack support (IPv4+IPv6) if supported by the operating system.
  ##
  ## Raises:
  ##   ObiwanError: If the server fails to bind to the specified port
  ##
  ## Example:
  ##   ```nim
  ##   proc handleRequest(req: Request) =
  ##     req.respond(Status.Success, "text/gemini", "# Hello from my Gemini server!")
  ##
  ##   let server = newObiwanServer(certFile="server.crt", keyFile="server.key")
  ##   server.serve(1965, handleRequest)
  ##   ```
  debug("Starting synchronous server on port " & $port)

  # Create server socket
  var serverSocket: mbedtls.mbedtls_net_context
  mbedtls.mbedtls_net_init(addr serverSocket)

  # Determine whether we're using IPv6
  let useIPv6 = address == "::" or (address.contains('[') or address.count(':') > 1)

  # Bind to address and port
  let bindAddr = if address == "":
                   if useIPv6: "::" else: "0.0.0.0"
                 else:
                   address
  var portStr = $port
  debug("Binding to " & bindAddr & ":" & portStr)

  # Bind to specified port
  let ret = mbedtls.mbedtls_net_bind(addr serverSocket,
                                  bindAddr.cstring,
                                  portStr.cstring,
                                  mbedtls.MBEDTLS_NET_PROTO_TCP)
  if ret != 0:
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret, cast[cstring](addr errorStr[0]), 100)
    raise newException(ObiwanError, "Failed to bind server socket: " & errorStr)

  # Determine socket type message for display
  let socketTypeMsg = if useIPv6:
    "IPv6" # Simple message - dual-stack support depends on OS configuration
  else:
    "IPv4"

  debug("Server bound to " & bindAddr & ":" & portStr & " using " & socketTypeMsg)
  # Only show server listening message if verbose level is 1 or higher
  if obiwan.debug.verbosityLevel > 0:
    echo "Server listening on " & bindAddr & ":" & portStr & " using " & socketTypeMsg

  # Accept loop
  while true:
    debug("Waiting for connection...")

    # Accept client connection
    var clientContext: mbedtls.mbedtls_net_context
    mbedtls.mbedtls_net_init(addr clientContext)

    let acceptRet = mbedtls.mbedtls_net_accept(addr serverSocket,
                                           addr clientContext,
                                           nil, 0, nil)
    if acceptRet != 0:
      debug("Failed to accept connection: " & $acceptRet)
      continue

    debug("Connection accepted, fd=" & $clientContext.fd)

    try:
      # Create socket wrapper
      var clientSocket = MbedtlsSocket(fd: clientContext.fd)

      # Get the SSL context from the server
      let ctx = MbedtlsSslContext(server.sslContext)

      # Initialize SSL on the client connection
      debug("Initializing SSL for client connection")
      tlsSocket.wrapConnectedSocket(ctx, clientSocket,
          tlsSocket.handshakeAsServer, "")

      # Read the request line
      debug("Reading request line")
      let line = clientSocket.recvLine()

      if line.len == 0:
        debug("Empty request, closing connection")
        clientSocket.close()
        continue

      debug("Received request: " & line)

      # Parse the request (Gemini URL)
      let url = parseUrl(line)

      # Get client certificate if available
      let sslCtx = clientSocket.getSslHandle()
      let clientCert = mbedtls.mbedtls_ssl_get_peer_cert(sslCtx)
      let verification = mbedtls.mbedtls_ssl_get_verify_result(sslCtx).int

      # Create request object
      let request = Request(
        url: url,
        certificate: clientCert,
        verification: verification,
        client: clientSocket
      )

      # Call the callback
      try:
        debug("Calling request handler")
        callback(request)
      except:
        let errMsg = getCurrentExceptionMsg()
        debug("Exception in request handler: " & errMsg)
        # Try to send an error response
        discard clientSocket.send($Status.Error.int & " INTERNAL SERVER ERROR\r\n")

      # Close connection after handling request
      debug("Closing connection after handling request")
      clientSocket.close()

    except:
      let errMsg = getCurrentExceptionMsg()
      debug("Error handling connection: " & errMsg)
      # Ensure we close the socket on error
      if clientContext.fd >= 0:
        mbedtls.mbedtls_net_free(addr clientContext)

# Forward declaration
proc handleAsyncClient(server: AsyncObiwanServer; clientSocket: AsyncSocket;
                      callback: proc(request: AsyncRequest): Future[
                          void]): Future[void] {.async.}

# Method to accept connections for asynchronous server
proc serve*(server: AsyncObiwanServer; port: int; callback: proc(
    request: AsyncRequest): Future[void]; address = ""): Future[
    void] {.async.} =
  ## Starts an asynchronous Gemini protocol server on the specified port.
  ##
  ## This function starts an asynchronous server that listens for incoming Gemini protocol
  ## requests without blocking the main thread. For each connection, it handles the TLS handshake,
  ## reads the request, and calls the provided async callback function with an AsyncRequest object.
  ## The callback is responsible for calling respond() to send a response.
  ##
  ## Although this function runs asynchronously, it still runs indefinitely until the Future
  ## is cancelled or the process is terminated.
  ##
  ## Parameters:
  ##   server: The AsyncObiwanServer instance created with newAsyncObiwanServer()
  ##   port: The port to listen on (standard Gemini port is 1965)
  ##   callback: An async procedure to call for each received request
  ##   address: Optional IP address to bind to (default: "0.0.0.0"). Use "::" for IPv6 with
  ##            possible dual-stack support (IPv4+IPv6) if supported by the operating system.
  ##
  ## Returns:
  ##   A Future that completes when the server stops running (which is normally never)
  ##
  ## Example:
  ##   ```nim
  ##   proc handleRequest(req: AsyncRequest) {.async.} =
  ##     req.respond(Status.Success, "text/gemini", "# Hello from my async Gemini server!")
  ##
  ##   proc main() {.async.} =
  ##     let server = newAsyncObiwanServer(certFile="server.crt", keyFile="server.key")
  ##     await server.serve(1965, handleRequest)
  ##
  ##   waitFor main()
  ##   ```
  debug("Starting asynchronous server on port " & $port)

  # Create an async server socket
  var serverSocket = newAsyncSocket()

  # Configure socket options
  if server.reuseAddr:
    serverSocket.setSockOpt(OptReuseAddr, true)
  if server.reusePort:
    serverSocket.setSockOpt(OptReusePort, true)

  # Determine whether to use IPv6, and whether to attempt dual-stack mode
  let useIPv6 = address == "::" or (address.contains('[') or address.count(':') > 1)

  if useIPv6:
    debug("Creating IPv6 socket")
    # Create IPv6 socket
    serverSocket = newAsyncSocket(Domain.AF_INET6)

    # Attempt to disable IPV6_V6ONLY for dual-stack mode
    # This is platform-specific and may not always work
    debug("Trying to enable dual-stack mode (IPv4+IPv6)")

    # We'll be more conservative and skip dual-stack configuration
    # This mode is OS-specific anyway, and some systems enable it by default
    # while others don't support it at all
    #
    # Users who need specific socket configurations should use their own
    # socket setup and pass it to the library

  # Determine binding address
  let bindAddr = if address == "" or address == "0.0.0.0":
                   if useIPv6: "::" else: "0.0.0.0"
                 else:
                   address

  debug("Binding async server to " & bindAddr & ":" & $port)
  serverSocket.bindAddr(Port(port), bindAddr)
  serverSocket.listen()

  # Determine what type of socket we're using for the user message
  let socketTypeMsg = if useIPv6:
    "IPv6" # Simple message - dual-stack support depends on OS configuration
  else:
    "IPv4"

  debug("Server listening on " & (if address == "" or address ==
      "0.0.0.0": "*" else: address) & ":" & $port & " using " & socketTypeMsg)
  # Only show server listening message if verbose level is 1 or higher
  if obiwan.debug.verbosityLevel > 0:
    echo "Async server listening on " & (if address == "" or address ==
        "0.0.0.0": "*" else: address) & ":" & $port & " using " & socketTypeMsg

  # Accept loop
  while true:
    # Wait for a new connection
    debug("Waiting for async connection...")

    # Accept incoming connection
    var clientSocket: AsyncSocket
    try:
      clientSocket = await serverSocket.accept()
      debug("Connection accepted, socket=" & $int(clientSocket.getFd()))
    except:
      let errMsg = getCurrentExceptionMsg()
      debug("Error accepting connection: " & errMsg)
      await sleepAsync(500) # Wait a bit before trying again
      continue

    # Process the connection in a separate async task
    asyncCheck handleAsyncClient(server, clientSocket, callback)

# Helper proc to handle async client in a separate task
proc handleAsyncClient(server: AsyncObiwanServer; clientSocket: AsyncSocket;
                       callback: proc(request: AsyncRequest): Future[
                           void]): Future[void] {.async.} =
  # Build socket wrapper
  var socket = newMbedtlsAsyncSocket()
  socket.fd = clientSocket.getFd().cint
  socket.sock = clientSocket.getFd().int
  socket.domain = if clientSocket.isSsl: posix.AF_INET else: 2 # Default to AF_INET

  try:
    # Get the SSL context from the server
    let ctx = MbedtlsSslContext(server.sslContext)

    # Initialize SSL on the client connection
    debug("Initializing SSL for async client connection")
    await tlsAsyncSocket.wrapConnectedSocket(ctx, socket,
        tlsAsyncSocket.handshakeAsServer, "")

    # Read the request line
    debug("Reading async request line")
    let line = await socket.recvLine()

    if line.len == 0:
      debug("Empty async request, closing connection")
      socket.close()
      return

    debug("Received async request: " & line)

    # Parse the request (Gemini URL)
    let url = parseUrl(line)

    # Get client certificate if available
    let sslCtx = socket.getSslHandle()
    let clientCert = mbedtls.mbedtls_ssl_get_peer_cert(sslCtx)
    let verification = mbedtls.mbedtls_ssl_get_verify_result(sslCtx).int

    # Create request object
    let request = AsyncRequest(
      url: url,
      certificate: clientCert,
      verification: verification,
      client: socket
    )

    # Call the callback
    try:
      debug("Calling async request handler")
      await callback(request)
    except:
      let errMsg = getCurrentExceptionMsg()
      debug("Exception in async request handler: " & errMsg)
      # Try to send an error response
      await socket.send($Status.Error.int & " INTERNAL SERVER ERROR\r\n")

    # Close connection after handling request
    debug("Closing async connection after handling request")
    socket.close()
  except:
    let errMsg = getCurrentExceptionMsg()
    debug("Error handling async connection: " & errMsg)
    # Ensure we close the socket on error
    socket.close()

# Server creation
proc newObiwanServer*(reuseAddr = true; reusePort = false; certFile = "";
    keyFile = ""; sessionId = ""): ObiwanServer =
  ## Creates a new synchronous Gemini protocol server.
  ##
  ## This function creates a synchronous server for handling Gemini protocol requests.
  ## A TLS certificate and private key are required for the server to function, as
  ## the Gemini protocol mandates secure connections.
  ##
  ## The server supports optional client certificate verification, which can be used
  ## to implement authentication. Client certificates are made available to request
  ## handlers through the Request.certificate property.
  ##
  ## Parameters:
  ##   reuseAddr: Allow reusing local addresses (default: true)
  ##   reusePort: Allow multiple bindings to same port (default: false)
  ##   certFile: Path to server certificate file in PEM format (required for production)
  ##   keyFile: Path to server private key file in PEM format (required for production)
  ##   sessionId: Optional custom session ID for TLS session resumption
  ##
  ## Returns:
  ##   A new ObiwanServer instance that can be used with serve()
  ##
  ## Raises:
  ##   ObiwanError: If certificate or key files cannot be loaded
  ##
  ## Note:
  ##   If sessionId is not provided, a random one will be generated.
  ##   For testing, you can omit certFile and keyFile, but for production use,
  ##   valid certificate and key files are required.
  result = ObiwanServer(reuseAddr: reuseAddr, reusePort: reusePort)

  # Create TLS context
  var actualContext = tlsSocket.newContext()
  # Store concrete context directly
  result.sslContext = actualContext

  # Configure for server mode
  discard mbedtls.mbedtls_ssl_config_defaults(
    addr actualContext.config,
    mbedtls.MBEDTLS_SSL_IS_SERVER,
    mbedtls.MBEDTLS_SSL_TRANSPORT_STREAM,
    mbedtls.MBEDTLS_SSL_PRESET_DEFAULT)

  # Load certificate and key
  if certFile != "" and keyFile != "":
    let ret1 = mbedtls.mbedtls_x509_crt_parse_file(addr actualContext.cert, certFile)
    if ret1 != 0:
      raise newException(ObiwanError, "Failed to parse certificate file")

    # Parse the key - platform-specific implementation
    debug("Loading private key from: " & keyFile)

    let ret2 =
      mbedtls.mbedtls_pk_parse_keyfile(
        addr actualContext.key, keyFile, nil,
        mbedtls.mbedtls_ctr_drbg_random, addr actualContext.ctr_drbg)

    if ret2 != 0:
      # Get a more detailed error message
      var errorStr = newString(100)
      mbedtls.mbedtls_strerror(ret2, cast[cstring](addr errorStr[0]), 100)
      raise newException(ObiwanError, "Failed to parse key file: " & errorStr &
          " (code: " & $ret2 & ")")

    # Configure certificate in SSL context
    let ret3 = mbedtls.mbedtls_ssl_conf_own_cert(addr actualContext.config,
                                          addr actualContext.cert,
                                          addr actualContext.key)
    if ret3 != 0:
      raise newException(ObiwanError, "Failed to set own certificate")

  # Set custom verify to allow self-signed client certificates
  tlsSocket.setCustomVerify(actualContext)

  # Set authentication mode to OPTIONAL - we don't want to require client certificates
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config,
      mbedtls.MBEDTLS_SSL_VERIFY_OPTIONAL)

  # Generate session ID if needed
  var id: string
  if sessionId == "":
    id = newString(32)
    randomize()
    discard randomBytes(id)
  else:
    id = sessionId

  # Set session ID
  # mbedtls doesn't have session ID context in this version, we'll implement it later
  #discard mbedtls.mbedtls_ssl_conf_session_id_context(addr actualContext.config, cast[ptr uint8](id.cstring), id.len.uint)

proc newAsyncObiwanServer*(reuseAddr = true; reusePort = false; certFile = "";
    keyFile = ""; sessionId = ""): AsyncObiwanServer =
  ## Creates a new asynchronous Gemini protocol server.
  ##
  ## This function creates an asynchronous server for handling Gemini protocol requests
  ## without blocking the main thread. A TLS certificate and private key are required for
  ## the server to function, as the Gemini protocol mandates secure connections.
  ##
  ## The server supports optional client certificate verification, which can be used
  ## to implement authentication. Client certificates are made available to request
  ## handlers through the AsyncRequest.certificate property.
  ##
  ## Parameters:
  ##   reuseAddr: Allow reusing local addresses (default: true)
  ##   reusePort: Allow multiple bindings to same port (default: false)
  ##   certFile: Path to server certificate file in PEM format (required for production)
  ##   keyFile: Path to server private key file in PEM format (required for production)
  ##   sessionId: Optional custom session ID for TLS session resumption
  ##
  ## Returns:
  ##   A new AsyncObiwanServer instance that can be used with serve()
  ##
  ## Raises:
  ##   ObiwanError: If certificate or key files cannot be loaded
  ##
  ## Note:
  ##   If sessionId is not provided, a random one will be generated.
  ##   For testing, you can omit certFile and keyFile, but for production use,
  ##   valid certificate and key files are required.
  result = AsyncObiwanServer(reuseAddr: reuseAddr, reusePort: reusePort)

  # Create TLS context
  var actualContext = tlsSocket.newContext()
  # Store concrete context directly
  result.sslContext = actualContext

  # Configure for server mode
  discard mbedtls.mbedtls_ssl_config_defaults(
    addr actualContext.config,
    mbedtls.MBEDTLS_SSL_IS_SERVER,
    mbedtls.MBEDTLS_SSL_TRANSPORT_STREAM,
    mbedtls.MBEDTLS_SSL_PRESET_DEFAULT)

  # Load certificate and key
  if certFile != "" and keyFile != "":
    let ret1 = mbedtls.mbedtls_x509_crt_parse_file(addr actualContext.cert, certFile)
    if ret1 != 0:
      raise newException(ObiwanError, "Failed to parse certificate file")

    # Parse the key - platform-specific implementation
    debug("Loading private key from: " & keyFile)

    let ret2 =
      mbedtls.mbedtls_pk_parse_keyfile(
        addr actualContext.key, keyFile, nil,
        mbedtls.mbedtls_ctr_drbg_random, addr actualContext.ctr_drbg)

    if ret2 != 0:
      # Get a more detailed error message
      var errorStr = newString(100)
      mbedtls.mbedtls_strerror(ret2, cast[cstring](addr errorStr[0]), 100)
      raise newException(ObiwanError, "Failed to parse key file: " & errorStr &
          " (code: " & $ret2 & ")")

    # Configure certificate in SSL context
    let ret3 = mbedtls.mbedtls_ssl_conf_own_cert(addr actualContext.config,
                                          addr actualContext.cert,
                                          addr actualContext.key)
    if ret3 != 0:
      raise newException(ObiwanError, "Failed to set own certificate")

  # Set custom verify to allow self-signed client certificates
  tlsSocket.setCustomVerify(actualContext)

  # Set authentication mode to OPTIONAL - we don't want to require client certificates
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config,
      mbedtls.MBEDTLS_SSL_VERIFY_OPTIONAL)

  # Generate session ID if needed
  var id: string
  if sessionId == "":
    id = newString(32)
    randomize()
    discard randomBytes(id)
  else:
    id = sessionId
