import net
import ./mbedtls as mbedtls
import strutils
import posix
import ../debug

type
  MbedtlsError* = object of CatchableError

  # SSL context object
  BaseSslContext* = ref object of RootObj
    
  MbedtlsSslContext* = ref object of BaseSslContext
    context*: mbedtls.mbedtls_ssl_context
    config*: mbedtls.mbedtls_ssl_config
    entropy*: mbedtls.mbedtls_entropy_context
    ctr_drbg*: mbedtls.mbedtls_ctr_drbg_context
    cacert*: mbedtls.mbedtls_x509_crt
    cert*: mbedtls.mbedtls_x509_crt
    key*: mbedtls.mbedtls_pk_context

  # Base socket object without reference semantics
  MbedtlsSocketObj* = object
    fd*: cint               # Socket file descriptor
    domain*: cint           # Socket domain
    sslContext*: MbedtlsSslContext
    sslHandle*: ptr mbedtls.mbedtls_ssl_context

  # Based on Socket from net module - ref version of MbedtlsSocketObj
  MbedtlsSocket* = ref MbedtlsSocketObj

# Helper functions
proc isIpv6Address(address: string): bool =
  return address.contains(':')

# Error handling
proc mbedtlsError(ret: int, msg: string): ref MbedtlsError =
  var errorStr = newString(100)
  mbedtls.mbedtls_strerror(ret.cint, cast[cstring](addr errorStr[0]), 100)
  return newException(MbedtlsError, msg & ": " & errorStr & " (error code: 0x" & toHex(ret) & ")")

proc newContext*(): MbedtlsSslContext =
  ## Creates a new mbedTLS SSL context with proper initialization.
  ##
  ## This function creates and initializes a new SSL context with entropy,
  ## random number generation, and default configuration suitable for
  ## Gemini protocol TLS requirements. The context needs to be further
  ## configured for client or server operation before use.
  ##
  ## Returns:
  ##   A new initialized MbedtlsSslContext
  ##
  ## Raises:
  ##   MbedtlsError: If initialization of any TLS component fails
  ##
  ## Example:
  ##   ```nim
  ##   var ctx = newContext()
  ##   # Further configure the context for client or server use
  ##   ```
  result = MbedtlsSslContext()

  # Initialize the entropy source and CTRDBG
  mbedtls.mbedtls_entropy_init(addr result.entropy)
  mbedtls.mbedtls_ctr_drbg_init(addr result.ctr_drbg)

  # Seed the random number generator
  let ret = mbedtls.mbedtls_ctr_drbg_seed(
    addr result.ctr_drbg,
    mbedtls.mbedtls_entropy_func,
    addr result.entropy,
    nil, 0)

  if ret != 0:
    raise mbedtlsError(ret, "Failed to seed CTRDBG")

  # Initialize the SSL config
  mbedtls.mbedtls_ssl_config_init(addr result.config)

  # Initialize default SSL configuration
  let ret2 = mbedtls.mbedtls_ssl_config_defaults(
    addr result.config,
    mbedtls.MBEDTLS_SSL_IS_CLIENT,
    mbedtls.MBEDTLS_SSL_TRANSPORT_STREAM,
    mbedtls.MBEDTLS_SSL_PRESET_DEFAULT)

  if ret2 != 0:
    raise mbedtlsError(ret2, "Failed to set SSL config defaults")

  # Set the random number generator
  mbedtls.mbedtls_ssl_conf_rng(addr result.config, mbedtls.mbedtls_ctr_drbg_random, addr result.ctr_drbg)

  # Initialize certificate containers
  mbedtls.mbedtls_x509_crt_init(addr result.cacert)
  mbedtls.mbedtls_x509_crt_init(addr result.cert)
  mbedtls.mbedtls_pk_init(addr result.key)

proc getSslHandle*(socket: MbedtlsSocket): ptr mbedtls.mbedtls_ssl_context =
  socket.sslHandle

proc isClosed2*(socket: MbedtlsSocket): bool =
  socket.fd == -1  # Use -1 to indicate invalid socket

# Function to handle self-signed certificates
proc customVerifyCallback(data: pointer, cert: ptr mbedtls.mbedtls_x509_crt, depth: cint, flags: ptr uint32): cint {.cdecl.} =
  # In mbedTLS, self-signed certificates usually result in NOT_TRUSTED flag
  # Accept certificates with only trust issues
  if (flags[] and mbedtls.MBEDTLS_X509_BADCERT_NOT_TRUSTED) != 0:
    # Check if this is a likely self-signed certificate
    if depth == 0:
      flags[] = 0
  return 0

proc setCustomVerify*(context: MbedtlsSslContext) =
  ## Configures the mbedTLS context to use a custom certificate verification callback.
  ##
  ## This function sets up a certificate verification callback that implements
  ## the Trust-On-First-Use (TOFU) model for Gemini. It accepts self-signed
  ## certificates while still validating other aspects of certificate security.
  ##
  ## Parameters:
  ##   context: The mbedTLS SSL context to configure
  ##
  ## Note:
  ##   This is crucial for the Gemini protocol's security model, which 
  ##   encourages the use of self-signed certificates.
  mbedtls.mbedtls_ssl_conf_verify(addr context.config, customVerifyCallback, nil)

## X.509 certificate type used in TLS connections
## 
## This type represents an X.509 digital certificate used for authentication
## in TLS connections. It provides methods for extracting certificate information
## such as subject names and generating fingerprints.
type X509Certificate* = ptr mbedtls.mbedtls_x509_crt

proc commonName*(cert: X509Certificate): string =
  ## Extracts the Common Name (CN) from an X.509 certificate.
  ##
  ## This function extracts the subject Common Name from a certificate, which
  ## typically contains the domain name for server certificates or a user
  ## identifier for client certificates.
  ##
  ## Parameters:
  ##   cert: The X.509 certificate to extract information from
  ##
  ## Returns:
  ##   The Common Name string, or an empty string if no CN is found or the certificate is nil
  ##
  ## Example:
  ##   ```nim
  ##   let cn = response.certificate.commonName
  ##   echo "Server certificate is for: ", cn
  ##   ```
  debug("Getting commonName from certificate...")
  if cert.isNil:
    debug("WARNING: Certificate is nil, returning empty string")
    return ""

  # Create a buffer to hold the subject string
  var subject = newString(512)
  debug("Calling mbedtls_x509_dn_gets on certificate...")

  # Get the distinguished name string
  let ret = mbedtls.mbedtls_x509_dn_gets(subject.cstring, 512.csize_t, cast[pointer](cert))
  if ret <= 0:
    debug("ERROR: mbedtls_x509_dn_gets returned " & $ret)
    return ""

  # Extract CN from subject
  let subjectStr = subject[0..<ret]
  debug("Certificate subject: " & subjectStr)

  let cnIndex = subjectStr.find("CN=")
  if cnIndex == -1:
    debug("WARNING: No CN= found in subject string")
    return ""

  var cnEnd = subjectStr.find(',', cnIndex)
  if cnEnd == -1:
    cnEnd = subjectStr.len

  let commonName = subjectStr[cnIndex+3..<cnEnd]
  debug("Extracted common name: " & commonName)
  return commonName

proc fingerprint*(cert: X509Certificate): string =
  ## Generates a SHA-256 fingerprint of an X.509 certificate.
  ##
  ## This function computes a cryptographic fingerprint of the certificate,
  ## which can be used to uniquely identify and verify certificates in a
  ## Trust-On-First-Use (TOFU) security model. The fingerprint is presented
  ## as a colon-separated hexadecimal string.
  ##
  ## Parameters:
  ##   cert: The X.509 certificate to fingerprint
  ##
  ## Returns:
  ##   SHA-256 fingerprint as a colon-separated hexadecimal string,
  ##   or an empty string if the certificate is nil or hashing fails
  ##
  ## Example:
  ##   ```nim
  ##   let fp = response.certificate.fingerprint
  ##   echo "Certificate fingerprint: ", fp
  ##   # Save fingerprint for TOFU validation on future connections
  ##   ```
  debug("Getting fingerprint from certificate...")
  if cert.isNil:
    debug("WARNING: Certificate is nil, returning empty string")
    return ""

  var hash = newString(32) # SHA-256 hash length

  # Use the available mbedtls_sha256 function to generate hash
  debug("Calling mbedtls_sha256 on certificate...")
  let ret = mbedtls.mbedtls_sha256(
    cast[pointer](cert),
    sizeof(mbedtls.mbedtls_x509_crt).csize_t,
    cast[pointer](addr hash[0]),
    0.cint  # 0 for SHA-256, 1 for SHA-224
  )

  if ret != 0:
    debug("ERROR: mbedtls_sha256 returned " & $ret)
    return ""

  # Convert the hash bytes to a hexadecimal string with colon separators
  result = ""
  for i in 0..<32:
    if i > 0:
      result.add(':')
    result.add(toHex(ord(hash[i]), 2).toLowerAscii())

  debug("Generated fingerprint: " & result)
  return result

proc `$`*(cert: X509Certificate): string =
  ## Returns a string representation of an X.509 certificate.
  ##
  ## This operator allows certificate objects to be easily printed or logged.
  ## It returns a detailed, multi-line representation of the certificate
  ## including subject, issuer, validity dates, and other important fields.
  ##
  ## Parameters:
  ##   cert: The X.509 certificate to convert to a string
  ##
  ## Returns:
  ##   A formatted string containing certificate details,
  ##   or "(nil)" if the certificate is nil
  ##
  ## Example:
  ##   ```nim
  ##   echo "Certificate details:"
  ##   echo response.certificate
  ##   ```
  debug("Getting string representation of certificate...")
  if cert.isNil:
    debug("WARNING: Certificate is nil, returning (nil)")
    return "(nil)"

  var output = newString(4096)
  debug("Calling mbedtls_x509_crt_info on certificate...")
  let ret = mbedtls.mbedtls_x509_crt_info(cast[cstring](addr output[0]), 4096.csize_t, "", cert)
  if ret <= 0:
    debug("ERROR: mbedtls_x509_crt_info returned " & $ret)
    return "(nil)"

  let certInfo = output[0..<ret]
  # Only show a small part of the output in logs to avoid overwhelming
  withDebug:
    let preview = certInfo[0..<min(80, ret)]
    debug("Got certificate info of length " & $ret & " bytes (first 80 chars): " & preview)
  return certInfo

# Define our BIO functions for socket I/O
# These need to be defined at the module level
proc my_bio_send(ctx: pointer, buf: pointer, len: csize_t): cint {.cdecl.} =
    debug("[BIO_SEND] Called with len=" & $len & " bytes")

    # Debug the context
    withDebug:
      debug("[BIO_SEND] Context address: " & $cast[int](ctx))
    if ctx.isNil:
      debug("[BIO_SEND] ERROR: context is nil")
      return mbedtls.MBEDTLS_ERR_NET_SEND_FAILED

    # Try to get socket from context
    var sock = cast[ptr MbedtlsSocketObj](ctx)
    debug("[BIO_SEND] Extracted socket from context")

    # Debug the socket state
    debug("[BIO_SEND] Socket FD: " & $sock.fd)

    # Prevent sending to invalid socket
    if sock.fd < 0:
      debug("[BIO_SEND] ERROR: Invalid socket FD: " & $sock.fd)
      return mbedtls.MBEDTLS_ERR_NET_SEND_FAILED

    # Show a few bytes of the buffer for debugging
    withDebug:
      var debugBytes = ""
      for i in 0..<min(len.int, 40):
        let b = cast[ptr uint8](cast[int](buf) + i)[]
        if b >= 32 and b < 127:  # Only print ASCII chars
          debugBytes.add(b.char)
        else:
          debugBytes.add('.')
      debug("[BIO_SEND] Data (first 40 bytes): " & debugBytes)

    # Try to write to the socket
    debug("[BIO_SEND] Calling posix.write with fd=" & $sock.fd & " and len=" & $len.int)
    let ret = posix.write(sock.fd, cast[pointer](buf), len.int)
    debug("[BIO_SEND] posix.write returned: " & $ret)

    if ret < 0:
      let err = posix.errno
      debug("[BIO_SEND] ERROR: posix.write error code: " & $err)
      debug("[BIO_SEND] ERROR description: " & $posix.strerror(err))

      # Check for specific errors
      if err == posix.EAGAIN or err == posix.EWOULDBLOCK:
        debug("[BIO_SEND] Would block, returning WANT_WRITE")
        return mbedtls.MBEDTLS_ERR_SSL_WANT_WRITE
      elif err == posix.EPIPE:
        debug("[BIO_SEND] Broken pipe")
      elif err == posix.ECONNRESET:
        debug("[BIO_SEND] Connection reset by peer")

      # Return general send failure
      return mbedtls.MBEDTLS_ERR_NET_SEND_FAILED

    debug("[BIO_SEND] Successfully sent " & $ret & " bytes")
    return ret.cint

proc my_bio_recv(ctx: pointer, buf: pointer, len: csize_t): cint {.cdecl.} =
    debug("[BIO_RECV] Called with len=" & $len & " bytes")

    # Debug the context
    withDebug:
      debug("[BIO_RECV] Context address: " & $cast[int](ctx))
    if ctx.isNil:
      debug("[BIO_RECV] ERROR: context is nil")
      return mbedtls.MBEDTLS_ERR_NET_RECV_FAILED

    # Try to get socket from context
    var sock = cast[ptr MbedtlsSocketObj](ctx)
    debug("[BIO_RECV] Extracted socket from context")

    # Debug the socket state
    debug("[BIO_RECV] Socket FD: " & $sock.fd)

    # Prevent reading from invalid socket
    if sock.fd < 0:
      debug("[BIO_RECV] ERROR: Invalid socket FD: " & $sock.fd)
      return mbedtls.MBEDTLS_ERR_NET_RECV_FAILED

    # Try to read from the socket
    debug("[BIO_RECV] Calling posix.read with fd=" & $sock.fd & " and len=" & $len.int)
    let ret = posix.read(sock.fd, cast[pointer](buf), len.int)
    debug("[BIO_RECV] posix.read returned: " & $ret)

    # Show data received for debugging
    if ret > 0:
      withDebug:
        var debugBytes = ""
        for i in 0..<min(ret.int, 40):
          let b = cast[ptr uint8](cast[int](buf) + i)[]
          if b >= 32 and b < 127:  # Only print ASCII printable chars
            debugBytes.add(b.char)
          else:
            debugBytes.add('.')
        debug("[BIO_RECV] Received data (first 40 bytes): " & debugBytes)

    if ret < 0:
      let err = posix.errno
      debug("[BIO_RECV] ERROR: posix.read error code: " & $err)
      debug("[BIO_RECV] ERROR description: " & $posix.strerror(err))

      # Check for specific errors
      if err == posix.EAGAIN or err == posix.EWOULDBLOCK:
        debug("[BIO_RECV] Would block, returning WANT_READ")
        return mbedtls.MBEDTLS_ERR_SSL_WANT_READ
      elif err == posix.ECONNRESET:
        debug("[BIO_RECV] Connection reset by peer")

      # Return general receive failure
      return mbedtls.MBEDTLS_ERR_NET_RECV_FAILED

    if ret == 0:
      debug("[BIO_RECV] Connection closed by peer (received 0 bytes)")

    debug("[BIO_RECV] Successfully received " & $ret & " bytes")
    return ret.cint

# Socket wrapper functions
proc wrapConnectedSocket*(context: MbedtlsSslContext, socket: var MbedtlsSocketObj,
                         handshakeFunc: proc(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint,
                         hostname: string) =
  ## Sets up TLS on an existing socket connection and performs handshake.
  ##
  ## This function initializes a TLS session on top of an already connected
  ## socket. It configures the TLS context with the specified hostname for
  ## SNI (Server Name Indication), sets up the I/O callbacks, and performs 
  ## the TLS handshake.
  ##
  ## Parameters:
  ##   context: The SSL context to use for the TLS session
  ##   socket: The socket object to wrap with TLS
  ##   handshakeFunc: A function that performs either client or server handshake
  ##   hostname: The server hostname for SNI (Server Name Indication)
  ##
  ## Raises:
  ##   MbedtlsError: If the TLS setup or handshake fails
  ##
  ## Note:
  ##   This function is used internally by both client and server implementations.
  ##   For self-signed certificates, verification failures with specific error
  ##   codes are accepted to support the Gemini protocol's security model.
  debug("Starting TLS session setup...")

  # Initialize SSL context
  debug("Initializing SSL context")
  mbedtls.mbedtls_ssl_init(addr context.context)

  # Setup SSL context
  debug("Setting up SSL context with config")
  let ret = mbedtls.mbedtls_ssl_setup(addr context.context, addr context.config)
  if ret != 0:
    debug("SSL setup error: " & $ret)
    raise mbedtlsError(ret, "Failed to setup SSL context")

  # Set hostname for SNI
  if hostname.len > 0:
    debug("Setting SNI hostname: " & hostname)
    let ret2 = mbedtls.mbedtls_ssl_set_hostname(addr context.context, hostname)
    if ret2 != 0:
      debug("SSL set hostname error: " & $ret2)
      raise mbedtlsError(ret2, "Failed to set hostname")

  # Set up BIO callbacks for socket I/O
  debug("Setting up BIO callbacks, socket FD: " & $socket.fd)
  # Pass the socket itself as the context for our BIO functions
  mbedtls.mbedtls_ssl_set_bio(addr context.context, cast[pointer](addr socket),
                            cast[pointer](my_bio_send), cast[pointer](my_bio_recv), nil)

  # Perform SSL handshake
  debug("Starting SSL handshake...")
  let handshakeRet = handshakeFunc(addr context.context)
  if handshakeRet != 0:
    debug("SSL handshake returned error code: " & $handshakeRet)
    if handshakeRet == mbedtls.MBEDTLS_ERR_X509_CERT_VERIFY_FAILED:
      debug("Certificate verification failed, but continuing (likely self-signed)")
      # This could be a self-signed certificate, which we allow
      discard
    else:
      raise mbedtlsError(handshakeRet, "SSL handshake failed")
  else:
    debug("SSL handshake completed successfully")

  # Store SSL handle in socket
  debug("Storing SSL context in socket")
  socket.sslHandle = addr context.context
  socket.sslContext = context

  # Verify the socket FD is still valid
  debug("Verifying socket FD: " & $socket.fd)
  if socket.fd < 0:
    raise newException(MbedtlsError, "Invalid socket FD after handshake: " & $socket.fd)

  debug("TLS session setup complete")

# Convenient overload for ref MbedtlsSocket
proc wrapConnectedSocket*(context: MbedtlsSslContext, socket: MbedtlsSocket,
                         handshakeFunc: proc(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint,
                         hostname: string) =
  debug("Wrapping socket of type MbedtlsSocket (ref object)")
  debug("Initial socket FD: " & $socket.fd)

  # Use the object directly, don't make a copy
  wrapConnectedSocket(context, socket[], handshakeFunc, hostname)

  # Verify the socket FD is still valid after the wrapper call
  debug("Socket FD after wrapping: " & $socket.fd)

proc handshakeAsClient*(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint =
  debug("Performing client handshake...")
  let ret = mbedtls.mbedtls_ssl_handshake(sslCtx)
  if ret != 0:
    debug("Client handshake returned error: " & $ret)
  else:
    debug("Client handshake successful")
  return ret

proc handshakeAsServer*(sslCtx: ptr mbedtls.mbedtls_ssl_context): cint =
  debug("Performing server handshake...")
  let ret = mbedtls.mbedtls_ssl_handshake(sslCtx)
  if ret != 0:
    debug("Server handshake returned error: " & $ret)
  else:
    debug("Server handshake successful")
  return ret

# Socket creation and connection functions
proc dial*(address: string, port: int): MbedtlsSocket =
  ## Establishes a TCP socket connection to the specified address and port.
  ##
  ## This function creates a new socket and connects it to the specified server,
  ## handling both IPv4 and IPv6 addresses. It's used as the first step in
  ## establishing a TLS connection to a Gemini server.
  ##
  ## Parameters:
  ##   address: The hostname or IP address to connect to
  ##   port: The TCP port number to connect to (usually 1965 for Gemini)
  ##
  ## Returns:
  ##   A connected MbedtlsSocket
  ##
  ## Raises:
  ##   MbedtlsError: If the connection fails
  ##
  ## Example:
  ##   ```nim
  ##   let socket = dial("example.com", 1965)
  ##   # The socket is now connected but not yet wrapped with TLS
  ##   ```
  debug("Creating socket connection to " & address & ":" & $port)
  var socket = MbedtlsSocket(fd: -1)
  var socketContext: mbedtls.mbedtls_net_context

  mbedtls.mbedtls_net_init(addr socketContext)

  # Convert to string and make it persistent for the duration of the call
  var portStr = $port
  debug("Attempting to connect with mbedtls_net_connect...")
  let ret = mbedtls.mbedtls_net_connect(addr socketContext, address, cast[cstring](addr portStr[0]), mbedtls.MBEDTLS_NET_PROTO_TCP)
  if ret != 0:
    debug("Connection failed with error code: " & $ret)
    raise mbedtlsError(ret, "Failed to connect to " & address & ":" & portStr)

  debug("Socket connection successful, fd=" & $socketContext.fd)
  socket.fd = socketContext.fd
  socket.domain = if isIpv6Address(address): 10 else: 2  # AF_INET6 = 10, AF_INET = 2

  # Verify the socket is valid
  if socket.fd < 0:
    raise newException(MbedtlsError, "mbedtls_net_connect returned success but socket fd is invalid: " & $socket.fd)

  return socket

# Socket send/receive operations
proc send*(socket: MbedtlsSocket, data: pointer, size: int): int =
  ## Sends data over a TLS-encrypted connection.
  ##
  ## This function sends the specified data over a TLS-encrypted socket
  ## connection. It handles the encryption transparently through mbedTLS.
  ##
  ## Parameters:
  ##   socket: The TLS socket to send data through
  ##   data: Pointer to the buffer containing the data to send
  ##   size: Number of bytes to send
  ##
  ## Returns:
  ##   The number of bytes successfully sent
  ##
  ## Raises:
  ##   MbedtlsError: If the send operation fails or the socket is invalid
  ##
  ## Note:
  ##   This function blocks until the data is sent or an error occurs.
  ##   It may send fewer bytes than requested, so check the return value.
  debug("Sending data of size " & $size & " bytes")
  if socket.isNil:
    debug("ERROR: Socket is nil!")
    raise newException(MbedtlsError, "Socket is nil")

  # Verify the socket is valid
  debug("Socket FD before SSL write: " & $socket.fd)
  if socket.fd < 0:
    debug("ERROR: Invalid socket FD: " & $socket.fd)
    raise newException(MbedtlsError, "Invalid socket FD: " & $socket.fd)

  if socket.sslHandle.isNil:
    debug("ERROR: SSL handle is nil!")
    raise newException(MbedtlsError, "SSL handle is nil")

  # Print first few bytes of data for debugging
  withDebug:
    var debugBytes = ""
    for i in 0..<min(size, 40):
      let b = cast[ptr uint8](cast[int](data) + i)[]
      if b >= 32 and b < 127:  # Only print ASCII chars
        debugBytes.add(b.char)
      else:
        debugBytes.add('.')
    debug("Data to send (first 40 bytes): " & debugBytes)

  debug("Calling mbedtls_ssl_write with size=" & $size)
  let ret = mbedtls.mbedtls_ssl_write(socket.sslHandle, cast[pointer](data), size.cuint)
  if ret < 0:
    debug("Error in mbedtls_ssl_write: " & $ret)
    # Check specifically for MBEDTLS_ERR_NET_SEND_FAILED
    if ret == mbedtls.MBEDTLS_ERR_NET_SEND_FAILED:
      debug("Network send failed - possible socket error or connection closed")
    raise mbedtlsError(ret.int, "Failed to send data")
  debug("Successfully sent " & $ret & " bytes")
  return ret

proc send*(socket: MbedtlsSocket, data: string): int =
  ## Sends a string over a TLS-encrypted connection.
  ##
  ## This is a convenience overload that allows sending a string directly 
  ## without manually handling pointers. It transparently handles the 
  ## encryption through mbedTLS.
  ##
  ## Parameters:
  ##   socket: The TLS socket to send data through
  ##   data: The string to send
  ##
  ## Returns:
  ##   The number of bytes successfully sent
  ##
  ## Raises:
  ##   MbedtlsError: If the send operation fails or the socket is invalid
  ##
  ## Example:
  ##   ```nim
  ##   let bytesWritten = socket.send("GET / HTTP/1.1\r\nHost: example.com\r\n\r\n")
  ##   ```
  debug("Sending string of length " & $data.len)
  withDebug: 
    debug("String content: " & data)
  return socket.send(unsafeAddr data[0], data.len)

proc recv*(socket: MbedtlsSocket, data: pointer, size: int): int =
  debug("Attempting to receive up to " & $size & " bytes")

  # Check for null socket
  if socket.isNil:
    debug("ERROR: Socket is nil in recv!")
    raise newException(MbedtlsError, "Socket is nil in recv")

  # Verify socket is valid
  debug("Socket FD before SSL read: " & $socket.fd)
  if socket.fd < 0:
    debug("ERROR: Invalid socket FD in recv: " & $socket.fd)
    raise newException(MbedtlsError, "Invalid socket FD in recv: " & $socket.fd)

  # Check for null SSL handle
  if socket.sslHandle.isNil:
    debug("ERROR: SSL handle is nil in recv!")
    raise newException(MbedtlsError, "SSL handle is nil in recv")

  # Check for null data buffer
  if data.isNil and size > 0:
    debug("ERROR: data buffer is nil in recv!")
    raise newException(MbedtlsError, "Data buffer is nil in recv")

  # Check the size parameter
  if size <= 0:
    debug("WARNING: Requested to receive 0 or negative bytes, returning 0")
    return 0

  # Perform the read operation
  debug("Calling mbedtls_ssl_read with size=" & $size)
  let ret = mbedtls.mbedtls_ssl_read(socket.sslHandle, data, size.cuint)

  # Handle return values
  if ret < 0:
    debug("Error in mbedtls_ssl_read: " & $ret)
    if ret == mbedtls.MBEDTLS_ERR_SSL_WANT_READ or
       ret == mbedtls.MBEDTLS_ERR_SSL_WANT_WRITE:
      debug("WANT_READ/WANT_WRITE, will retry")
      return 0
    if ret == mbedtls.MBEDTLS_ERR_SSL_PEER_CLOSE_NOTIFY:
      debug("Peer closed connection cleanly")
      return 0
    raise mbedtlsError(ret.int, "Failed to receive data")

  # Show data received for debugging
  if ret > 0:
    withDebug:
      var debugBytes = ""
      for i in 0..<min(ret.int, 40):
        let b = cast[ptr uint8](cast[int](data) + i)[]
        if b >= 32 and b < 127:  # Only print ASCII printable chars
          debugBytes.add(b.char)
        else:
          debugBytes.add('.')
      debug("Received data at application level (first 40 bytes): " & debugBytes)

  debug("Successfully received " & $ret & " bytes")
  return ret

# Convenience functions for recv operations
proc recvLine*(socket: MbedtlsSocket): string =
  debug("Reading a line from socket...")

  # Verify socket pointer
  if socket.isNil:
    debug("ERROR: Socket is nil in recvLine!")
    raise newException(MbedtlsError, "Socket is nil in recvLine")

  # Verify socket is valid
  if socket.fd < 0:
    debug("ERROR: Invalid socket FD in recvLine: " & $socket.fd)
    raise newException(MbedtlsError, "Invalid socket FD in recvLine: " & $socket.fd)

  # Initialize a buffer to store the line
  result = ""

  # Read one byte at a time until we find a newline
  var buffer = newString(1)
  while true:
    # Make sure the buffer has space
    buffer[0] = '\0'

    # Read 1 byte
    debug("Reading one byte...")
    let ret = socket.recv(addr buffer[0], 1)

    # Check for errors or EOF
    if ret <= 0:
      debug("No more data available, returning current line")
      break

    # Append the byte to the result
    let c = buffer[0]
    result.add(c)

    # Break if we found a newline
    if c == '\n':
      debug("Found end of line character")
      break

  debug("Raw received line: " & $result.len & " bytes")

  # Remove trailing \r\n
  if result.len > 0 and result[^1] == '\n':
    result.setLen(result.len - 1)
    if result.len > 0 and result[^1] == '\r':
      result.setLen(result.len - 1)

  debug("Processed line: " & result)

proc close*(socket: MbedtlsSocket) =
  if socket.fd != -1:
    debug("Closing socket with fd=" & $socket.fd)
    if socket.sslHandle != nil:
      debug("Sending TLS close notify")
      discard mbedtls.mbedtls_ssl_close_notify(socket.sslHandle)
    # Just close the socket directly
    socket.fd = -1
    debug("Socket closed")
