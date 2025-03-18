## Common types and protocols
import uri
import streams
import asyncdispatch
import net

# Export specific symbols from dependency modules
export uri.Uri, Port

type
  # Forward declaration (to be defined in TLS modules)
  X509Certificate* = pointer
  ## X.509 certificate type used for TLS certificate operations.
  ##
  ## This is a forward declaration that is concretely defined in the TLS modules.
  ## It represents an X.509 certificate used in TLS connections for both client
  ## and server authentication in the Gemini protocol.

  Status* = enum
    ## Gemini protocol status codes, organized in categories:
    ## - 1x: Input (10-19)
    ## - 2x: Success (20-29)
    ## - 3x: Redirect (30-39)
    ## - 4x: Temporary Failure (40-49)
    ## - 5x: Permanent Failure (50-59)
    ## - 6x: Client Certificate Required (60-69)
    ##
    ## See spec/protocol-specification.gmi for the official specification.
    Input = 10, ## Client request requires additional user input
    SensitiveInput = 11, ## Client request requires sensitive input (e.g. password)
    Success = 20, ## Request was successful, content follows
    TempRedirect = 30, ## Resource temporarily available at different URL
    Redirect = 31, ## Resource permanently available at different URL
    TempError = 40, ## Temporary server failure
    ServerUnavailable = 41, ## Server unavailable due to capacity issues
    CGIError = 42, ## CGI script failure
    ProxyError = 43, ## Request failed due to proxy error
    Slowdown = 44, ## Client should slow down requests
    Error = 50, ## Permanent server failure
    NotFound = 51, ## Resource not found
    Gone = 52, ## Resource permanently gone
    ProxyRefused = 53, ## Proxy request refused
    MalformedRequest = 59, ## Malformed request syntax
    CertificateRequired = 60, ## Client certificate required
    CertificateUnauthorized = 61, ## Certificate not authorized for resource
    CertificateNotValid = 62 ## Certificate not valid or expired

  ObiwanError* = object of CatchableError
    ## Base exception type for all ObiWAN library errors.
    ##
    ## This exception is raised for various error conditions within the ObiWAN library,
    ## including network errors, TLS handshake failures, protocol errors, and
    ## certificate handling problems.
    ##
    ## Example:
    ##   ```nim
    ##   try:
    ##     let client = newObiwanClient()
    ##     let response = client.request("gemini://example.com/")
    ##   except ObiwanError as e:
    ##     echo "Error: ", e.msg
    ##   ```

  # Generic types to allow code sharing between sync/async variants
  ObiwanClientBase*[SocketType] = ref object
    ## Base client type for Gemini protocol implementation. Generic over socket type
    ## to support both synchronous and asynchronous operations.
    ##
    ## Use the concrete types `ObiwanClient` and `AsyncObiwanClient` in application code.
    socket*: SocketType ## Socket connection to server
    maxRedirects*: Natural ## Maximum number of redirects to follow (default: 5)
    sslContext*: SslContext ## TLS/SSL context for secure connection
    bodyStreamVariant*: tuple[isFutureStream: bool] ## Internal type marker
    bodyStreamSync*: Stream ## Stream for body content in synchronous mode
    bodyStreamAsync*: FutureStream[string] ## Stream for body content in async mode
    parseBodyFut*: Future[void] ## Future for tracking body parsing

  ResponseBase*[ClientType] = ref object
    ## Response from a Gemini server. Provides access to status code, meta string,
    ## and server certificate information. Generic over client type to support
    ## both synchronous and asynchronous implementations.
    ##
    ## Use the concrete types `Response` and `AsyncResponse` in application code.
    status*: Status ## Response status (see Status enum)
    meta*: string ## Meta information (MIME type for success responses, redirection target, error details, etc.)
    certificate*: X509Certificate ## Server's X.509 certificate (nil if not provided)
    verification*: int ## Certificate verification result (0 = verified, other values indicate verification issues)
    client*: ClientType ## Reference to client that created this response

  ObiwanServerBase*[SocketType] = ref object
    ## Base server type for Gemini protocol implementation. Generic over socket type
    ## to support both synchronous and asynchronous operations.
    ##
    ## Use the concrete types `ObiwanServer` and `AsyncObiwanServer` in application code.
    socket*: SocketType ## Server listening socket
    reuseAddr*: bool ## Allow reuse of local addresses (default: true)
    reusePort*: bool ## Allow multiple bindings to same port (default: false)
    sslContext*: SslContext ## TLS/SSL context for secure connections

  RequestBase*[SocketType] = ref object
    ## Request from a client in a Gemini server. Contains the requested URL,
    ## client certificate information (if provided), and the client socket.
    ##
    ## Use the concrete types `Request` and `AsyncRequest` in application code.
    url*: Uri ## Requested URL, can be used to handle virtual hosts, resources, and query parameters
    certificate*: X509Certificate ## Client's X.509 certificate (nil if not provided)
    verification*: int ## Certificate verification result (0 = verified, other values indicate verification issues)
    client*: SocketType ## Client socket connection

  # We use a dynamic binding at runtime, so the static type
  # just needs to be compatible with the concrete implementation
  SslContext* = RootRef
    ## Base type for SSL/TLS context objects.
    ##
    ## This abstract type serves as a base for concrete TLS implementation contexts.
    ## It's implemented as a RootRef for runtime polymorphism, allowing different
    ## underlying TLS implementations to be used through a common interface.
    ##
    ## The actual implementation used by ObiWAN is mbedTLS, with the concrete type
    ## being MbedtlsSslContext.

# Certificate verification helper methods
proc isSelfSigned*(transaction: RequestBase | ResponseBase): bool =
  ## Determines if a certificate is likely self-signed by checking verification flags.
  ##
  ## Returns `true` when the certificate has only trust issues but no other validation
  ## problems, which typically indicates a self-signed certificate. This is common
  ## in the Gemini ecosystem where many servers use self-signed certificates.
  ##
  ## This helps implement the Trust-On-First-Use (TOFU) security model recommended
  ## for Gemini clients.
  ##
  ## Parameters:
  ##   transaction: A request or response object containing certificate information
  ##
  ## Returns:
  ##   `true` if the certificate appears to be self-signed, `false` otherwise
  const BADCERT_NOT_TRUSTED = 1 shl 0 # Corresponds to MBEDTLS_X509_BADCERT_NOT_TRUSTED
  return (transaction.verification and BADCERT_NOT_TRUSTED) != 0 and
         transaction.verification == BADCERT_NOT_TRUSTED

proc isVerified*(transaction: RequestBase | ResponseBase): bool =
  ## Checks if a certificate chain is fully verified against a trusted root.
  ##
  ## Returns `true` when the certificate chain is verified up to a known trusted
  ## root certificate with no verification issues. This typically means the certificate
  ## was issued by a Certificate Authority that the system trusts.
  ##
  ## Parameters:
  ##   transaction: A request or response object containing certificate information
  ##
  ## Returns:
  ##   `true` if the certificate is fully verified, `false` otherwise
  return transaction.verification == 0

proc hasCertificate*(transaction: RequestBase | ResponseBase): bool =
  ## Checks if a certificate is present in the transaction.
  ##
  ## This is useful to determine if a client or server provided a certificate
  ## during the TLS handshake, which is optional in the Gemini protocol.
  ##
  ## Parameters:
  ##   transaction: A request or response object
  ##
  ## Returns:
  ##   `true` if a certificate is present, `false` otherwise
  not transaction.certificate.isNil

proc toStatus*(code: int): Status =
  ## Safely converts an integer status code to a Status enum value.
  ##
  ## This helper function maps numeric Gemini response codes to their corresponding
  ## Status enum values. It performs safe conversion and defaults to Status.Error
  ## for any unrecognized status codes.
  ##
  ## Parameters:
  ##   code: An integer status code (typically from a Gemini response)
  ##
  ## Returns:
  ##   The corresponding Status enum value, or Status.Error for unknown codes
  ##
  ## Note: This avoids the Nim "enum with holes" warning when directly converting integers to enums.
  case code
  of 10: Status.Input
  of 11: Status.SensitiveInput
  of 20: Status.Success
  of 30: Status.TempRedirect
  of 31: Status.Redirect
  of 40: Status.TempError
  of 41: Status.ServerUnavailable
  of 42: Status.CGIError
  of 43: Status.ProxyError
  of 44: Status.Slowdown
  of 50: Status.Error
  of 51: Status.NotFound
  of 52: Status.Gone
  of 53: Status.ProxyRefused
  of 59: Status.MalformedRequest
  of 60: Status.CertificateRequired
  of 61: Status.CertificateUnauthorized
  of 62: Status.CertificateNotValid
  else: Status.Error # Default to error for unknown codes
