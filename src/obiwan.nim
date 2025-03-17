## ObiWAN Gemini protocol library

# Standard library imports
import asyncdispatch
import asyncnet
import random
import nimcrypto
import strutils
import uri
import streams
import net
import posix

# Core components
import obiwan/common
import obiwan/debug

# TLS implementation
import obiwan/tls/mbedtls as mbedtls
import obiwan/tls/socket as tlsSocket
import obiwan/tls/async_socket as tlsAsyncSocket

# Only declare the platform-specific version we need
when defined(isMacOS):
  # Function for macOS - use our custom define
  proc parseKeyFile*(ctx: ptr tlsSocket.MbedtlsSslContext; keyFile: string): cint =
    # macOS requires 5 parameters
    mbedtls.mbedtls_pk_parse_keyfile(addr ctx.key, keyFile, nil, mbedtls.mbedtls_ctr_drbg_random, addr ctx.ctr_drbg)
else:
  # Function for Linux and other platforms
  proc parseKeyFile*(ctx: ptr tlsSocket.MbedtlsSslContext; keyFile: string): cint =
    # Linux only requires 3 parameters
    mbedtls.mbedtls_pk_parse_keyfile(addr ctx.key, keyFile, nil)

# Concrete type aliases for TLS implementation
type
  X509Certificate* = tlsSocket.X509Certificate
  MbedtlsError* = tlsSocket.MbedtlsError

  # Socket types
  MbedtlsSocket* = tlsSocket.MbedtlsSocket
  MbedtlsSocketObj* = tlsSocket.MbedtlsSocketObj
  MbedtlsAsyncSocket* = tlsAsyncSocket.MbedtlsAsyncSocket
  MbedtlsAsyncSocketObj* = tlsAsyncSocket.MbedtlsAsyncSocketObj

  # Context types - type alias for implementation
  MbedtlsSslContext* = tlsSocket.MbedtlsSslContext
  # Use the BaseSslContext as our SslContext
  SslContext* = tlsSocket.BaseSslContext

  # Client types
  ObiwanClient* = ObiwanClientBase[MbedtlsSocket]
  AsyncObiwanClient* = ObiwanClientBase[MbedtlsAsyncSocket]

  # Response types
  Response* = ResponseBase[ObiwanClient]
  AsyncResponse* = ResponseBase[AsyncObiwanClient]

  # Server types
  ObiwanServer* = ObiwanServerBase[MbedtlsSocket]
  AsyncObiwanServer* = ObiwanServerBase[MbedtlsAsyncSocket]

  # Request types
  Request* = RequestBase[MbedtlsSocket]
  AsyncRequest* = RequestBase[MbedtlsAsyncSocket]

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

# Certificate handling is available through the tlsSocket module

# Client API
proc loadIdentityFile*(client: ObiwanClient | AsyncObiwanClient; certFile, keyFile: string): bool =
  ## Load a pair of certificate/key files in PEM format to be offered to the server
  # Use the context directly as MbedtlsSslContext
  let ctx = MbedtlsSslContext(client.sslContext)

  let ret1 = mbedtls.mbedtls_x509_crt_parse_file(addr ctx.cert, certFile)
  if ret1 != 0:
    return false

  # Use unified function
  let ret2 = parseKeyFile(unsafeAddr ctx, keyFile)
  if ret2 != 0:
    return false

  # Configure certificate in SSL context
  let ret3 = mbedtls.mbedtls_ssl_conf_own_cert(addr ctx.config,
                                          addr ctx.cert,
                                          addr ctx.key)
  if ret3 != 0:
    return false

  return true


proc newObiwanClient*(maxRedirects = 5, certFile = "", keyFile = ""): ObiwanClient =
  ## Create a new synchronous Gemini client
  ## Optionally, a certificate-based identity can be offered to the server
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
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config, mbedtls.MBEDTLS_SSL_VERIFY_NONE)

  if certFile != "" and keyFile != "":
    if not result.loadIdentityFile(certFile, keyFile):
      raise newException(ObiwanError, "Failed to load certificate files.")

proc newAsyncObiwanClient*(maxRedirects = 5, certFile = "", keyFile = ""): AsyncObiwanClient =
  ## Create a new asynchronous Gemini client
  ## Optionally, a certificate-based identity can be offered to the server
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
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config, mbedtls.MBEDTLS_SSL_VERIFY_NONE)

  if certFile != "" and keyFile != "":
    if not result.loadIdentityFile(certFile, keyFile):
      raise newException(ObiwanError, "Failed to load certificate files.")

proc loadUrl(client: ObiwanClient | AsyncObiwanClient, url: string): Future[Response | AsyncResponse] {.multisync.} =
  ## Internal helper function to load a URL
  let uri = parseUri(url)
  let port = if uri.port == "": 1965 else: parseInt(uri.port)
  if uri.scheme != "gemini":
    raise newException(ObiwanError, url & ": scheme not supported")

  # Use the context directly as MbedtlsSslContext
  let ctx = MbedtlsSslContext(client.sslContext)

  when client is AsyncObiwanClient:
    result = AsyncResponse(client: client)
    client.socket = await tlsAsyncSocket.dial(uri.hostname, port)
    await tlsAsyncSocket.wrapConnectedSocket(ctx, client.socket, tlsAsyncSocket.handshakeAsClient, uri.hostname)
    # send data now to force TLS handshake to complete
    await client.socket.send(url & "\r\n")
  else:
    result = Response(client: client)
    client.socket = tlsSocket.dial(uri.hostname, port)
    tlsSocket.wrapConnectedSocket(ctx, client.socket, tlsSocket.handshakeAsClient, uri.hostname)
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

proc request*(client: ObiwanClient | AsyncObiwanClient, url: string): Future[Response | AsyncResponse] {.multisync.} =
  ## Retrieve status and meta from a server for a given url, handling redirects.
  ## On success, the connection is kept open.
  ## Get the body with response.body
  var url = url
  result = await client.loadUrl(url)
  for i in 1..client.maxRedirects:
    if result.status == Status.Redirect or result.status == Status.TempRedirect:
      url = $combine(parseUri(url), parseUri(result.meta))
      result = await client.loadUrl(url)
    else:
      return
  client.socket.close()
  raise newException(ObiwanError, "too many redirects")

proc body*(response: Response | AsyncResponse): Future[string] {.multisync.} =
  ## Get the body associated with a response.
  ## The connection is closed once the body has been retrieved.
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
  ## Close the client's connection
  if not client.socket.isNil():
    client.socket.close()

# Server API
proc respond*(req: Request | AsyncRequest, status: Status, meta: string, body: string = "") {.multisync.} =
  ## Sends data back to a client as per the gemini protocol
  ## meta cannot be more than 1024 characters
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
  except:
    echo getCurrentExceptionMsg()
    when req is AsyncRequest:
      await req.client.send($Status.Error.int & " INTERNAL ERROR\r\n")
    else:
      discard req.client.send($Status.Error.int & " INTERNAL ERROR\r\n")

# Method to accept connections for synchronous server
proc serve*(server: ObiwanServer, port: int, callback: proc(request: Request), address = "") =
  ## Start a server on the given port and call the callback for each client request
  ## This is a blocking operation
  debug("Starting synchronous server on port " & $port)

  # Create server socket
  var serverSocket: mbedtls.mbedtls_net_context
  mbedtls.mbedtls_net_init(addr serverSocket)

  # Bind to address and port
  let bindAddr = if address == "": "0.0.0.0" else: address
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

  debug("Server bound to " & bindAddr & ":" & portStr)
  echo "Server listening on " & bindAddr & ":" & portStr

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
      tlsSocket.wrapConnectedSocket(ctx, clientSocket, tlsSocket.handshakeAsServer, "")

      # Read the request line
      debug("Reading request line")
      let line = clientSocket.recvLine()

      if line.len == 0:
        debug("Empty request, closing connection")
        clientSocket.close()
        continue

      debug("Received request: " & line)

      # Parse the request (Gemini URL)
      let url = parseUri(line)

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
proc handleAsyncClient(server: AsyncObiwanServer, clientSocket: AsyncSocket,
                      callback: proc(request: AsyncRequest): Future[void]): Future[void] {.async.}

# Method to accept connections for asynchronous server
proc serve*(server: AsyncObiwanServer, port: int, callback: proc(request: AsyncRequest): Future[void], address = ""): Future[void] {.async.} =
  ## Start an async server on the given port and call the callback for each client request
  ## This is a non-blocking operation
  debug("Starting asynchronous server on port " & $port)

  # Create an async server socket
  var serverSocket = newAsyncSocket()

  # Configure socket options
  if server.reuseAddr:
    serverSocket.setSockOpt(OptReuseAddr, true)
  if server.reusePort:
    serverSocket.setSockOpt(OptReusePort, true)

  # Bind and start listening
  let bindAddr = if address == "" or address == "0.0.0.0": "0.0.0.0"
                 elif address == "::": "::"
                 else: address

  debug("Binding async server to " & bindAddr & ":" & $port)
  serverSocket.bindAddr(Port(port), bindAddr)
  serverSocket.listen()

  debug("Server listening on " & (if address == "" or address == "0.0.0.0": "*" else: address) & ":" & $port)
  echo "Async server listening on " & (if address == "" or address == "0.0.0.0": "*" else: address) & ":" & $port

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
proc handleAsyncClient(server: AsyncObiwanServer, clientSocket: AsyncSocket,
                       callback: proc(request: AsyncRequest): Future[void]): Future[void] {.async.} =
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
    await tlsAsyncSocket.wrapConnectedSocket(ctx, socket, tlsAsyncSocket.handshakeAsServer, "")

    # Read the request line
    debug("Reading async request line")
    let line = await socket.recvLine()

    if line.len == 0:
      debug("Empty async request, closing connection")
      socket.close()
      return

    debug("Received async request: " & line)

    # Parse the request (Gemini URL)
    let url = parseUri(line)

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
proc newObiwanServer*(reuseAddr = true; reusePort = false, certFile = "", keyFile = "", sessionId = ""): ObiwanServer =
  ## Creates a new server, certFile and keyFile are used to handle the TLS handshake
  ## If a sessionId is not provided it is generated randomly and is used by TLS to resume sessions
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

    # Use unified function with address-of operator
    let ret2 = parseKeyFile(addr actualContext, keyFile)
    if ret2 != 0:
      raise newException(ObiwanError, "Failed to parse key file")

    # Configure certificate in SSL context
    let ret3 = mbedtls.mbedtls_ssl_conf_own_cert(addr actualContext.config,
                                          addr actualContext.cert,
                                          addr actualContext.key)
    if ret3 != 0:
      raise newException(ObiwanError, "Failed to set own certificate")

  # Set custom verify to allow self-signed client certificates
  tlsSocket.setCustomVerify(actualContext)

  # Set authentication mode to OPTIONAL - we don't want to require client certificates
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config, mbedtls.MBEDTLS_SSL_VERIFY_OPTIONAL)

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

proc newAsyncObiwanServer*(reuseAddr = true; reusePort = false, certFile = "", keyFile = "", sessionId = ""): AsyncObiwanServer =
  ## Creates a new async server, certFile and keyFile are used to handle the TLS handshake
  ## If a sessionId is not provided it is generated randomly and is used by TLS to resume sessions
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

    # Use unified function with address-of operator
    let ret2 = parseKeyFile(addr actualContext, keyFile)
    if ret2 != 0:
      raise newException(ObiwanError, "Failed to parse key file")

    # Configure certificate in SSL context
    let ret3 = mbedtls.mbedtls_ssl_conf_own_cert(addr actualContext.config,
                                          addr actualContext.cert,
                                          addr actualContext.key)
    if ret3 != 0:
      raise newException(ObiwanError, "Failed to set own certificate")

  # Set custom verify to allow self-signed client certificates
  tlsSocket.setCustomVerify(actualContext)

  # Set authentication mode to OPTIONAL - we don't want to require client certificates
  mbedtls.mbedtls_ssl_conf_authmode(addr actualContext.config, mbedtls.MBEDTLS_SSL_VERIFY_OPTIONAL)

  # Generate session ID if needed
  var id: string
  if sessionId == "":
    id = newString(32)
    randomize()
    discard randomBytes(id)
  else:
    id = sessionId
