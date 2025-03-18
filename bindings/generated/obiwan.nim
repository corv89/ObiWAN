import bumpy, chroma, unicode, vmath

export bumpy, chroma, unicode, vmath

when defined(windows):
  const libName = "obiwan.dll"
elif defined(macosx):
  const libName = "libobiwan.dylib"
else:
  const libName = "libobiwan.so"

{.push dynlib: libName.}

type obiwanError = object of ValueError

type Status* = enum
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

type ObiwanClientObj = object
  reference: pointer

type ObiwanClient* = ref ObiwanClientObj

proc obiwan_obiwan_client_unref(x: ObiwanClientObj) {.importc: "obiwan_obiwan_client_unref", cdecl.}

proc `=destroy`(x: var ObiwanClientObj) =
  obiwan_obiwan_client_unref(x)

type ObiwanServerObj = object
  reference: pointer

type ObiwanServer* = ref ObiwanServerObj

proc obiwan_obiwan_server_unref(x: ObiwanServerObj) {.importc: "obiwan_obiwan_server_unref", cdecl.}

proc `=destroy`(x: var ObiwanServerObj) =
  obiwan_obiwan_server_unref(x)

type ResponseObj = object
  reference: pointer

type Response* = ref ResponseObj

proc obiwan_response_unref(x: ResponseObj) {.importc: "obiwan_response_unref", cdecl.}

proc `=destroy`(x: var ResponseObj) =
  obiwan_response_unref(x)

proc obiwan_new_obiwan_client(max_redirects: int, cert_file: cstring,
    key_file: cstring): ObiwanClient {.importc: "obiwan_new_obiwan_client", cdecl.}

proc newObiwanClient*(maxRedirects: int = 5, certFile: string = "",
    keyFile: string = ""): ObiwanClient {.inline.} =
  result = obiwan_new_obiwan_client(maxRedirects, certFile.cstring,
      keyFile.cstring)

proc obiwan_obiwan_client_get_max_redirects(
  obiwanClient: ObiwanClient): Natural {.importc: "obiwan_obiwan_client_get_max_redirects", cdecl.}

proc maxRedirects*(obiwanClient: ObiwanClient): Natural {.inline.} =
  obiwan_obiwan_client_get_max_redirects(obiwanClient)

proc obiwan_obiwan_client_set_max_redirects(obiwanClient: ObiwanClient,
    maxRedirects: Natural) {.importc: "obiwan_obiwan_client_set_max_redirects", cdecl.}

proc `maxRedirects=`*(obiwanClient: ObiwanClient, maxRedirects: Natural) =
  obiwan_obiwan_client_set_max_redirects(obiwanClient, maxRedirects)

proc obiwan_obiwan_client_request(client: ObiwanClient,
    url: cstring): Response {.importc: "obiwan_obiwan_client_request", cdecl.}

proc request*(client: ObiwanClient, url: string): Response {.inline.} =
  result = obiwan_obiwan_client_request(client, url.cstring)

proc obiwan_obiwan_client_close(client: ObiwanClient) {.importc: "obiwan_obiwan_client_close", cdecl.}

proc close*(client: ObiwanClient) {.inline.} =
  obiwan_obiwan_client_close(client)

proc obiwan_new_obiwan_server(reuse_addr: bool, reuse_port: bool,
    cert_file: cstring, key_file: cstring,
    session_id: cstring): ObiwanServer {.importc: "obiwan_new_obiwan_server", cdecl.}

proc newObiwanServer*(reuseAddr: bool = true, reusePort: bool = false,
    certFile: string = "", keyFile: string = "",
    sessionId: string = ""): ObiwanServer {.inline.} =
  result = obiwan_new_obiwan_server(reuseAddr, reusePort, certFile.cstring,
      keyFile.cstring, sessionId.cstring)

proc obiwan_obiwan_server_get_reuse_addr(
  obiwanServer: ObiwanServer): bool {.importc: "obiwan_obiwan_server_get_reuse_addr", cdecl.}

proc reuseAddr*(obiwanServer: ObiwanServer): bool {.inline.} =
  obiwan_obiwan_server_get_reuse_addr(obiwanServer)

proc obiwan_obiwan_server_set_reuse_addr(obiwanServer: ObiwanServer,
    reuseAddr: bool) {.importc: "obiwan_obiwan_server_set_reuse_addr", cdecl.}

proc `reuseAddr=`*(obiwanServer: ObiwanServer, reuseAddr: bool) =
  obiwan_obiwan_server_set_reuse_addr(obiwanServer, reuseAddr)

proc obiwan_obiwan_server_get_reuse_port(
  obiwanServer: ObiwanServer): bool {.importc: "obiwan_obiwan_server_get_reuse_port", cdecl.}

proc reusePort*(obiwanServer: ObiwanServer): bool {.inline.} =
  obiwan_obiwan_server_get_reuse_port(obiwanServer)

proc obiwan_obiwan_server_set_reuse_port(obiwanServer: ObiwanServer,
    reusePort: bool) {.importc: "obiwan_obiwan_server_set_reuse_port", cdecl.}

proc `reusePort=`*(obiwanServer: ObiwanServer, reusePort: bool) =
  obiwan_obiwan_server_set_reuse_port(obiwanServer, reusePort)

proc obiwan_response_get_status(response: Response): Status {.importc: "obiwan_response_get_status", cdecl.}

proc status*(response: Response): Status {.inline.} =
  obiwan_response_get_status(response)

proc obiwan_response_set_status(response: Response,
    status: Status) {.importc: "obiwan_response_set_status", cdecl.}

proc `status=`*(response: Response, status: Status) =
  obiwan_response_set_status(response, status)

proc obiwan_response_get_meta(response: Response): cstring {.importc: "obiwan_response_get_meta", cdecl.}

proc meta*(response: Response): cstring {.inline.} =
  obiwan_response_get_meta(response).`$`

proc obiwan_response_set_meta(response: Response,
    meta: cstring) {.importc: "obiwan_response_set_meta", cdecl.}

proc `meta=`*(response: Response, meta: string) =
  obiwan_response_set_meta(response, meta.cstring)

proc obiwan_response_body(response: Response): cstring {.importc: "obiwan_response_body", cdecl.}

proc body*(response: Response): cstring {.inline.} =
  result = obiwan_response_body(response)

proc obiwan_response_has_certificate(transaction: Response): bool {.importc: "obiwan_response_has_certificate", cdecl.}

proc hasCertificate*(transaction: Response): bool {.inline.} =
  result = obiwan_response_has_certificate(transaction)

proc obiwan_response_is_verified(transaction: Response): bool {.importc: "obiwan_response_is_verified", cdecl.}

proc isVerified*(transaction: Response): bool {.inline.} =
  result = obiwan_response_is_verified(transaction)

proc obiwan_response_is_self_signed(transaction: Response): bool {.importc: "obiwan_response_is_self_signed", cdecl.}

proc isSelfSigned*(transaction: Response): bool {.inline.} =
  result = obiwan_response_is_self_signed(transaction)

proc obiwan_check_error(): bool {.importc: "obiwan_check_error", cdecl.}

proc checkError*(): bool {.inline.} =
  result = obiwan_check_error()

proc obiwan_take_error(): cstring {.importc: "obiwan_take_error", cdecl.}

proc takeError*(): cstring {.inline.} =
  result = obiwan_take_error()

