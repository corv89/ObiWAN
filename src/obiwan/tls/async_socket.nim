import asyncdispatch
import net
import posix # For low-level socket functions
import ./mbedtls as mbedtls
import strutils
import ./socket
import ../debug

# Helper functions for async socket waiting
proc waitForReadable(socket: AsyncFD): Future[void] =
  ## Creates a Future that completes when the socket becomes readable.
  ##
  ## This is an internal helper function used to implement non-blocking I/O
  ## with asynchronous TLS operations. It registers a callback with the async
  ## dispatcher that will complete the returned future when data is available to read.
  ##
  ## Parameters:
  ##   socket: The AsyncFD socket descriptor to wait on
  ##
  ## Returns:
  ##   A Future[void] that completes when data is available to read
  var future = newFuture[void]("waitForReadable")
  proc cb(fd: AsyncFD): bool =
    future.complete()
    return true
  addRead(socket, cb)
  return future

proc waitForWritable(socket: AsyncFD): Future[void] =
  ## Creates a Future that completes when the socket becomes writable.
  ##
  ## This is an internal helper function used to implement non-blocking I/O
  ## with asynchronous TLS operations. It registers a callback with the async
  ## dispatcher that will complete the returned future when the socket is ready for writing.
  ##
  ## Parameters:
  ##   socket: The AsyncFD socket descriptor to wait on
  ##
  ## Returns:
  ##   A Future[void] that completes when the socket is ready for writing
  var future = newFuture[void]("waitForWritable")
  proc cb(fd: AsyncFD): bool =
    future.complete()
    return true
  addWrite(socket, cb)
  return future

# Base async socket object
type
  ## Object representing an asynchronous TLS socket.
  ##
  ## This type encapsulates a non-blocking socket with TLS encryption
  ## capabilities, designed for use with Nim's asyncdispatch module.
  ## It provides asynchronous I/O operations for Gemini protocol communication.
  MbedtlsAsyncSocketObj* = object
    fd*: cint                                   ## Socket file descriptor
    domain*: cint                               ## Socket domain (AF_INET or AF_INET6)
    isBuffered*: bool                           ## Whether the socket uses buffering
    buffer*: string                             ## Buffer for received data
    sendQueue*: string                          ## Queue for data to be sent
    isSsl*: bool                                ## Whether TLS is enabled
    sock*: int ## AsyncFD representation (AsyncFD is an int wrapper)
    sslContext*: MbedtlsSslContext              ## SSL context for TLS operations
    sslHandle*: ptr mbedtls.mbedtls_ssl_context ## Handle to mbedTLS SSL context

  ## Reference type for asynchronous TLS socket.
  ##
  ## This is the primary type used for async TLS communication in the Gemini protocol.
  ## It provides high-level methods for non-blocking TLS-encrypted network operations.
  MbedtlsAsyncSocket* = ref MbedtlsAsyncSocketObj

proc getSslHandle*(socket: MbedtlsAsyncSocket): ptr mbedtls.mbedtls_ssl_context =
  ## Retrieves the mbedTLS SSL context handle from an async socket.
  ##
  ## This function provides access to the underlying mbedTLS SSL context,
  ## which can be used for direct TLS operations or certificate inspection.
  ##
  ## Parameters:
  ##   socket: The async socket to get the SSL handle from
  ##
  ## Returns:
  ##   Pointer to the mbedTLS SSL context
  socket.sslHandle

proc newMbedtlsAsyncSocket*(): MbedtlsAsyncSocket =
  ## Creates a new asynchronous TLS socket.
  ##
  ## This function initializes a new socket object for asynchronous TLS
  ## communication. The socket is not yet connected or associated with
  ## a file descriptor - use the dial() function to establish a connection.
  ##
  ## Returns:
  ##   A newly created MbedtlsAsyncSocket
  ##
  ## Example:
  ##   ```nim
  ##   let socket = newMbedtlsAsyncSocket()
  ##   socket = await dial("example.com", 1965)
  ##   ```
  new(result)
  result.fd = -1 # Invalid FD until connected
  result.domain = 2 # Domain.AF_INET default
  result.isBuffered = true # Enable buffering
  result.buffer = "" # Empty buffer
  result.sendQueue = "" # Empty send queue
  result.isSsl = true
  result.sslHandle = nil
  result.sock = -1 # asyncInvalidSocket

proc isClosed*(socket: MbedtlsAsyncSocket): bool =
  ## Checks if an async socket is closed.
  ##
  ## This function determines whether the socket has been closed
  ## by checking if the file descriptor is invalid.
  ##
  ## Parameters:
  ##   socket: The async socket to check
  ##
  ## Returns:
  ##   `true` if the socket is closed, `false` otherwise
  ##
  ## Example:
  ##   ```nim
  ##   if socket.isClosed:
  ##     socket = await dial("example.com", 1965)
  ##   ```
  socket.fd == -1

# Async socket operations
proc dial*(address: string, port: int): Future[MbedtlsAsyncSocket] {.async.} =
  ## Asynchronously establishes a TCP connection to the specified address and port.
  ##
  ## This function creates a new async socket and connects it to the specified server,
  ## handling both IPv4 and IPv6 addresses. It configures the socket for non-blocking
  ## operation and registers it with the async dispatcher.
  ##
  ## Parameters:
  ##   address: The hostname or IP address to connect to
  ##   port: The TCP port number to connect to (usually 1965 for Gemini)
  ##
  ## Returns:
  ##   A Future that completes with a connected MbedtlsAsyncSocket
  ##
  ## Raises:
  ##   OSError: If the connection fails
  ##
  ## Example:
  ##   ```nim
  ##   let socket = await dial("example.com", 1965)
  ##   # The socket is now connected but not yet wrapped with TLS
  ##   ```
  var socket = newMbedtlsAsyncSocket()

  # Create the socket FD
  var socketContext: mbedtls.mbedtls_net_context
  mbedtls.mbedtls_net_init(addr socketContext)

  # Connect to server
  var portStr = $port
  let ret = mbedtls.mbedtls_net_connect(addr socketContext, address, cast[
      cstring](addr portStr[0]), mbedtls.MBEDTLS_NET_PROTO_TCP)
  if ret != 0:
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret, cast[cstring](addr errorStr[0]), 100)
    raise newException(OSError, "Failed to connect to " & address & ":" &
        portStr & ": " & errorStr)

  # Set non-blocking mode
  discard mbedtls.mbedtls_net_set_nonblock(addr socketContext)

  # Assign the socket fd
  socket.fd = socketContext.fd
  # Detect IPv6 addresses for proper socket domain
  # IPv6 addresses have multiple colons and may be enclosed in square brackets
  socket.domain = if address.contains('[') or address.count(':') >
      1: 10 else: 2 # AF_INET6 = 10, AF_INET = 2

  # Register with async dispatcher
  socket.sock = socket.fd # AsyncFD is just an int wrapper
  asyncdispatch.register(asyncdispatch.AsyncFD(socket.fd))

  return socket

proc wrapConnectedSocketObj*(context: MbedtlsSslContext, socket: ref MbedtlsAsyncSocketObj,
                          handshakeFunc: proc(
                              sslCtx: ptr mbedtls_ssl_context): cint,
                          hostname: string) {.async.} =
  ## Asynchronously sets up TLS on an existing socket connection and performs handshake.
  ##
  ## This function initializes a TLS session on top of an already connected
  ## socket. It configures the TLS context with the specified hostname for
  ## SNI (Server Name Indication), sets up the I/O callbacks, and performs
  ## the TLS handshake asynchronously, handling WANT_READ/WANT_WRITE conditions.
  ##
  ## Parameters:
  ##   context: The SSL context to use for the TLS session
  ##   socket: The socket object to wrap with TLS
  ##   handshakeFunc: A function that performs either client or server handshake
  ##   hostname: The server hostname for SNI (Server Name Indication)
  ##
  ## Raises:
  ##   OSError: If the TLS setup or handshake fails
  ##
  ## Note:
  ##   This is an internal function used by the higher-level wrapConnectedSocket.
  ##   For self-signed certificates, verification failures with specific error
  ##   codes are accepted to support the Gemini protocol's security model.
  debug("Starting async TLS session setup...")

  # Initialize SSL context
  debug("Initializing SSL context")
  mbedtls.mbedtls_ssl_init(addr context.context)

  # Setup SSL context with config
  debug("Setting up SSL context with config")
  let ret = mbedtls.mbedtls_ssl_setup(addr context.context, addr context.config)
  if ret != 0:
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret, cast[cstring](addr errorStr[0]), 100)
    debug("SSL setup error: " & errorStr)
    raise newException(OSError, "Failed to setup SSL context: " & errorStr)

  # Set hostname for SNI
  if hostname.len > 0:
    let ret2 = mbedtls.mbedtls_ssl_set_hostname(addr context.context, hostname)
    if ret2 != 0:
      var errorStr = newString(100)
      mbedtls.mbedtls_strerror(ret2, cast[cstring](addr errorStr[0]), 100)
      raise newException(OSError, "Failed to set hostname: " & errorStr)

  # Custom socket I/O for async operations
  proc asyncSend(ctx: pointer, buf: pointer, len: uint): cint {.cdecl.} =
    let sock = cast[MbedtlsAsyncSocket](ctx)
    var ret: int
    try:
      # Use a simple direct write with the fd
      ret = posix.write(sock.fd, buf, len.int).int
      if ret <= 0:
        return mbedtls.MBEDTLS_ERR_SSL_WANT_WRITE
      return ret.cint
    except:
      return mbedtls.MBEDTLS_ERR_NET_SEND_FAILED

  proc asyncRecv(ctx: pointer, buf: pointer, len: uint): cint {.cdecl.} =
    let sock = cast[MbedtlsAsyncSocket](ctx)
    var ret: int
    try:
      # Use a simple direct read with the fd
      ret = posix.read(sock.fd, buf, len.int).int
      if ret <= 0:
        if posix.errno == posix.EAGAIN or posix.errno == posix.EWOULDBLOCK:
          return mbedtls.MBEDTLS_ERR_SSL_WANT_READ
        return mbedtls.MBEDTLS_ERR_NET_RECV_FAILED
      return ret.cint
    except:
      return mbedtls.MBEDTLS_ERR_NET_RECV_FAILED

  # Connect bio with socket
  mbedtls.mbedtls_ssl_set_bio(addr context.context, cast[pointer](socket),
      asyncSend, asyncRecv, nil)

  # Perform SSL handshake (async)
  var handshakeRet = handshakeFunc(addr context.context)
  while handshakeRet == mbedtls.MBEDTLS_ERR_SSL_WANT_READ or
        handshakeRet == mbedtls.MBEDTLS_ERR_SSL_WANT_WRITE:
    if handshakeRet == mbedtls.MBEDTLS_ERR_SSL_WANT_READ:
      await waitForReadable(asyncdispatch.AsyncFD(socket.sock))
    else:
      await waitForWritable(asyncdispatch.AsyncFD(socket.sock))
    handshakeRet = handshakeFunc(addr context.context)

  if handshakeRet != 0:
    if handshakeRet == mbedtls.MBEDTLS_ERR_X509_CERT_VERIFY_FAILED:
      # This could be a self-signed certificate, which we allow
      discard
    else:
      var errorStr = newString(100)
      mbedtls.mbedtls_strerror(handshakeRet, cast[cstring](addr errorStr[0]), 100)
      raise newException(OSError, "SSL handshake failed: " & errorStr)

  # Store SSL handle and context in socket
  socket.sslHandle = addr context.context
  socket.sslContext = context

# Convenient wrapper for ref version
proc wrapConnectedSocket*(context: MbedtlsSslContext, socket: MbedtlsAsyncSocket,
                         handshakeFunc: proc(
                             sslCtx: ptr mbedtls.mbedtls_ssl_context): cint,
                         hostname: string) {.async.} =
  await wrapConnectedSocketObj(context, socket, handshakeFunc, hostname)

proc handshakeAsServer*(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint =
  debug("Performing async server handshake...")
  let ret = mbedtls.mbedtls_ssl_handshake(sslCtx)
  if ret != 0:
    debug("Async server handshake returned error: " & $ret)
  else:
    debug("Async server handshake successful")
  return ret

proc handshakeAsClient*(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint =
  debug("Performing async client handshake...")
  let ret = mbedtls.mbedtls_ssl_handshake(sslCtx)
  if ret != 0:
    debug("Async client handshake returned error: " & $ret)
  else:
    debug("Async client handshake successful")
  return ret

proc send*(socket: MbedtlsAsyncSocket, data: string) {.async.} =
  ## Asynchronously sends data over a TLS-encrypted connection.
  ##
  ## This function sends the specified string over a TLS-encrypted socket
  ## connection without blocking. It handles the encryption transparently
  ## through mbedTLS and manages asynchronous I/O with WANT_READ/WANT_WRITE
  ## conditions. It ensures all data is sent, potentially over multiple
  ## operations.
  ##
  ## Parameters:
  ##   socket: The TLS async socket to send data through
  ##   data: The string data to send
  ##
  ## Raises:
  ##   OSError: If the send operation fails or the socket is invalid
  ##
  ## Example:
  ##   ```nim
  ##   await socket.send("gemini://example.com/\r\n")
  ##   ```
  debug("Sending data of size " & $data.len & " bytes")
  var sent = 0
  while sent < data.len:
    let toSend = data[sent..^1]
    withDebug:
      if toSend.len > 0:
        var preview = toSend[0..min(40, toSend.len-1)]
        debug("Data to send (first bytes): " & preview)

    debug("Calling mbedtls_ssl_write with size=" & $toSend.len)
    var ret = mbedtls.mbedtls_ssl_write(socket.sslHandle, cast[pointer](
        unsafeAddr toSend[0]), toSend.len.cuint)

    if ret == mbedtls.MBEDTLS_ERR_SSL_WANT_WRITE:
      debug("SSL_WANT_WRITE, waiting for socket to be writable")
      await waitForWritable(asyncdispatch.AsyncFD(socket.sock))
      continue

    if ret == mbedtls.MBEDTLS_ERR_SSL_WANT_READ:
      debug("SSL_WANT_READ, waiting for socket to be readable")
      await waitForReadable(asyncdispatch.AsyncFD(socket.sock))
      continue

    if ret < 0:
      var errorStr = newString(100)
      mbedtls.mbedtls_strerror(ret, cast[cstring](addr errorStr[0]), 100)
      debug("Error in mbedtls_ssl_write: " & errorStr)
      raise newException(OSError, "Failed to send data: " & errorStr)

    debug("Successfully sent " & $ret & " bytes")
    sent += ret.int

proc recv*(socket: MbedtlsAsyncSocket, size: int): Future[string] {.async.} =
  ## Asynchronously receives data from a TLS-encrypted connection.
  ##
  ## This function reads up to the specified number of bytes from a TLS-encrypted
  ## socket connection without blocking. It handles the decryption transparently
  ## through mbedTLS and manages asynchronous I/O with WANT_READ/WANT_WRITE
  ## conditions.
  ##
  ## Parameters:
  ##   socket: The TLS async socket to receive data from
  ##   size: Maximum number of bytes to receive
  ##
  ## Returns:
  ##   A Future that completes with the received data as a string.
  ##   The length may be less than the requested size if the connection
  ##   was closed or if a partial read occurred.
  ##
  ## Raises:
  ##   OSError: If the receive operation fails
  ##
  ## Example:
  ##   ```nim
  ##   let data = await socket.recv(1024)
  ##   echo "Received ", data.len, " bytes"
  ##   ```
  debug("Attempting to receive up to " & $size & " bytes")
  var data = newString(size)
  var bytesReceived = 0

  while bytesReceived < size:
    debug("Calling mbedtls_ssl_read with size=" & $(size - bytesReceived))
    var ret = mbedtls.mbedtls_ssl_read(socket.sslHandle,
                                     cast[pointer](addr data[bytesReceived]),
                                     (size - bytesReceived).cuint)

    if ret == mbedtls.MBEDTLS_ERR_SSL_WANT_READ:
      debug("SSL_WANT_READ, waiting for socket to be readable")
      await waitForReadable(asyncdispatch.AsyncFD(socket.sock))
      continue

    if ret == mbedtls.MBEDTLS_ERR_SSL_WANT_WRITE:
      debug("SSL_WANT_WRITE, waiting for socket to be writable")
      await waitForWritable(asyncdispatch.AsyncFD(socket.sock))
      continue

    if ret == 0 or ret == mbedtls.MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY:
      # Connection closed by peer
      debug("Peer closed connection")
      data.setLen(bytesReceived)
      break

    if ret < 0:
      # Actual error
      var errorStr = newString(100)
      mbedtls.mbedtls_strerror(ret, cast[cstring](addr errorStr[0]), 100)
      debug("Error in mbedtls_ssl_read: " & errorStr)
      raise newException(OSError, "Failed to receive data: " & errorStr)

    debug("Successfully received " & $ret & " bytes")
    bytesReceived += ret.int

    # Show data received for debugging
    if ret > 0:
      withDebug:
        let bytes = min(ret.int, 40)
        let preview = data[bytesReceived-ret.int..<bytesReceived-ret.int+bytes]
        var debugBytes = ""
        for c in preview:
          if ord(c) >= 32 and ord(c) < 127: # Only print ASCII printable chars
            debugBytes.add(c)
          else:
            debugBytes.add('.')
        debug("Received data (first " & $bytes & " bytes): " & debugBytes)

    if bytesReceived < size:
      # We have more data available immediately
      data.setLen(bytesReceived)
      break

  return data

proc recvLine*(socket: MbedtlsAsyncSocket): Future[string] {.async.} =
  ## Asynchronously reads a line of text from a TLS-encrypted connection.
  ##
  ## This function reads bytes one at a time until it encounters a newline character,
  ## making it suitable for line-based protocols like Gemini. It automatically
  ## handles CRLF line endings by trimming both CR and LF characters.
  ##
  ## Parameters:
  ##   socket: The TLS async socket to read from
  ##
  ## Returns:
  ##   A Future that completes with the line read from the socket,
  ##   with trailing CR and LF characters removed
  ##
  ## Raises:
  ##   EOFError: If the connection is closed and no data was read
  ##   OSError: If there's an error reading from the socket
  ##
  ## Example:
  ##   ```nim
  ##   let response = await socket.recvLine()
  ##   echo "Received response header: ", response
  ##   ```
  debug("Reading a line from async socket...")
  result = ""
  while true:
    debug("Reading one byte...")
    var c = await socket.recv(1)
    if c.len == 0:
      # We've been disconnected
      debug("No more data available, returning current line")
      if result.len == 0:
        raise newException(EOFError, "Disconnected")
      break

    result.add(c)
    if c == "\n":
      debug("Found end of line character")
      break

  debug("Raw received line: " & $result.len & " bytes")

  # Remove trailing \r\n
  if result.len > 0 and result[^1] == '\n':
    result.setLen(result.len - 1)
    if result.len > 0 and result[^1] == '\r':
      result.setLen(result.len - 1)

  debug("Processed line: " & result)

proc close*(socket: MbedtlsAsyncSocket) =
  ## Closes an async TLS socket and frees associated resources.
  ##
  ## This function performs a clean shutdown of the TLS connection by sending
  ## a close notify alert, unregisters the socket from the async dispatcher,
  ## and marks the socket as closed. This should be called when you're done
  ## with a connection to properly free resources.
  ##
  ## Parameters:
  ##   socket: The async TLS socket to close
  ##
  ## Example:
  ##   ```nim
  ##   await socket.send("QUIT\r\n")
  ##   socket.close()
  ##   ```
  if socket.fd != -1:
    debug("Closing async socket with fd=" & $socket.fd)
    if socket.sslHandle != nil:
      debug("Sending TLS close notify")
      discard mbedtls.mbedtls_ssl_close_notify(socket.sslHandle)

    # Unregister from async dispatcher if needed
    if socket.sock != -1:
      debug("Unregistering from async dispatcher")
      try:
        asyncdispatch.unregister(asyncdispatch.AsyncFD(socket.sock))
      except CatchableError:
        debug("Error during unregister (ignoring)")
      socket.sock = -1

    # Set fd to -1 to mark it as closed
    socket.fd = -1
    debug("Async socket closed")
