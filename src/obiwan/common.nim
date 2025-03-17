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

  Status* = enum
    ## See spec/protocol-specification.gmi
    Input = 10
    SensitiveInput = 11
    Success = 20
    TempRedirect = 30
    Redirect = 31
    TempError = 40
    ServerUnavailable = 41
    CGIError = 42
    ProxyError = 43
    Slowdown = 44
    Error = 50
    NotFound = 51
    Gone = 52
    ProxyRefused = 53
    MalformedRequest = 59
    CertificateRequired = 60
    CertificateUnauthorized = 61
    CertificateNotValid = 62

  ObiwanError* = object of CatchableError

  # Generic types to allow code sharing between sync/async variants
  ObiwanClientBase*[SocketType] = ref object
    socket*: SocketType
    maxRedirects*: Natural
    sslContext*: SslContext
    bodyStreamVariant*: tuple[isFutureStream: bool]
    bodyStreamSync*: Stream
    bodyStreamAsync*: FutureStream[string]
    parseBodyFut*: Future[void]

  ResponseBase*[ClientType] = ref object
    status*: Status
    meta*: string
    certificate*: X509Certificate
    verification*: int
    client*: ClientType

  ObiwanServerBase*[SocketType] = ref object
    socket*: SocketType
    reuseAddr*: bool
    reusePort*: bool
    sslContext*: SslContext

  RequestBase*[SocketType] = ref object
    ## Request from a client.
    ## The url can be used to handle virtual hosts resource and query parameters
    url*: Uri
    certificate*: X509Certificate
    verification*: int
    client*: SocketType # This should be a ref object

  # We use a dynamic binding at runtime, so the static type
  # just needs to be compatible with the concrete implementation
  SslContext* = RootRef

# Certificate verification helper methods
proc isSelfSigned*(transaction: RequestBase | ResponseBase): bool =
  ## is true when the certificate is likely self-signed (has only trust issues)
  const BADCERT_NOT_TRUSTED = 1 shl 0  # Corresponds to MBEDTLS_X509_BADCERT_NOT_TRUSTED
  return (transaction.verification and BADCERT_NOT_TRUSTED) != 0 and
         transaction.verification == BADCERT_NOT_TRUSTED

proc isVerified*(transaction: RequestBase | ResponseBase): bool =
  ## is true when the certificate chain is verified up to a known root certificate
  return transaction.verification == 0

proc hasCertificate*(transaction: RequestBase | ResponseBase): bool =
  not transaction.certificate.isNil

proc toStatus*(code: int): Status =
  ## Safely convert an integer status code to a Status enum value
  ## This avoids the "enum with holes" warning
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
  else: Status.Error  # Default to error for unknown codes
