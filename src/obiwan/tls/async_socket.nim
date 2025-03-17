import asyncdispatch
import net
import posix # For low-level socket functions
import ./mbedtls as mbedtls
import strutils
import ./socket
import ../debug

# Helper functions for async socket waiting
proc waitForReadable(socket: AsyncFD): Future[void] =
  var future = newFuture[void]("waitForReadable")
  proc cb(fd: AsyncFD): bool =
    future.complete()
    return true
  addRead(socket, cb)
  return future

proc waitForWritable(socket: AsyncFD): Future[void] =
  var future = newFuture[void]("waitForWritable")
  proc cb(fd: AsyncFD): bool =
    future.complete()
    return true
  addWrite(socket, cb)
  return future

# Base async socket object
type
  MbedtlsAsyncSocketObj* = object
    fd*: cint
    domain*: cint
    isBuffered*: bool
    buffer*: string
    sendQueue*: string
    isSsl*: bool
    sock*: int # AsyncFD is an int
    sslContext*: MbedtlsSslContext
    sslHandle*: ptr mbedtls.mbedtls_ssl_context

  MbedtlsAsyncSocket* = ref MbedtlsAsyncSocketObj

proc getSslHandle*(socket: MbedtlsAsyncSocket): ptr mbedtls.mbedtls_ssl_context =
  socket.sslHandle

proc newMbedtlsAsyncSocket*(): MbedtlsAsyncSocket =
  new(result)
  result.fd = -1
  result.domain = 2 # Domain.AF_INET
  result.isBuffered = true
  result.buffer = ""
  result.sendQueue = ""
  result.isSsl = true
  result.sslHandle = nil
  result.sock = -1 # asyncInvalidSocket

proc isClosed*(socket: MbedtlsAsyncSocket): bool =
  socket.fd == -1

# Async socket operations
proc dial*(address: string, port: int): Future[MbedtlsAsyncSocket] {.async.} =
  var socket = newMbedtlsAsyncSocket()

  # Create the socket FD
  var socketContext: mbedtls.mbedtls_net_context
  mbedtls.mbedtls_net_init(addr socketContext)

  # Connect to server
  var portStr = $port
  let ret = mbedtls.mbedtls_net_connect(addr socketContext, address, cast[cstring](addr portStr[0]), mbedtls.MBEDTLS_NET_PROTO_TCP)
  if ret != 0:
    var errorStr = newString(100)
    mbedtls.mbedtls_strerror(ret, cast[cstring](addr errorStr[0]), 100)
    raise newException(OSError, "Failed to connect to " & address & ":" & portStr & ": " & errorStr)

  # Set non-blocking mode
  discard mbedtls.mbedtls_net_set_nonblock(addr socketContext)

  # Assign the socket fd
  socket.fd = socketContext.fd
  socket.domain = if address.contains(':'): 10 else: 2 # AF_INET6 = 10, AF_INET = 2

  # Register with async dispatcher
  socket.sock = socket.fd # AsyncFD is just an int wrapper
  asyncdispatch.register(asyncdispatch.AsyncFD(socket.fd))

  return socket

proc wrapConnectedSocketObj*(context: MbedtlsSslContext, socket: ref MbedtlsAsyncSocketObj,
                          handshakeFunc: proc(sslCtx: ptr mbedtls_ssl_context): cint,
                          hostname: string) {.async.} =
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
  mbedtls.mbedtls_ssl_set_bio(addr context.context, cast[pointer](socket), asyncSend, asyncRecv, nil)

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
                         handshakeFunc: proc(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint,
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
  debug("Sending data of size " & $data.len & " bytes")
  var sent = 0
  while sent < data.len:
    let toSend = data[sent..^1]
    withDebug:
      if toSend.len > 0:
        var preview = toSend[0..min(40, toSend.len-1)]
        debug("Data to send (first bytes): " & preview)
    
    debug("Calling mbedtls_ssl_write with size=" & $toSend.len)
    var ret = mbedtls.mbedtls_ssl_write(socket.sslHandle, cast[pointer](unsafeAddr toSend[0]), toSend.len.cuint)

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
          if ord(c) >= 32 and ord(c) < 127:  # Only print ASCII printable chars
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
      except:
        debug("Error during unregister (ignoring)")
      socket.sock = -1

    # Set fd to -1 to mark it as closed
    socket.fd = -1
    debug("Async socket closed")
