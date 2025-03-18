when not defined(gcArc) and not defined(gcOrc):
  {.error: "Please use --gc:arc or --gc:orc when using Genny.".}

when (NimMajor, NimMinor, NimPatch) == (1, 6, 2):
  {.error: "Nim 1.6.2 not supported with Genny due to FFI issues.".}
proc obiwan_obiwan_client_unref*(x: ObiwanClient) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(x)

proc obiwan_new_obiwan_client*(max_redirects: int, cert_file: cstring, key_file: cstring): ObiwanClient {.raises: [], cdecl, exportc, dynlib.} =
  newObiwanClient(max_redirects, cert_file.`$`, key_file.`$`)

proc obiwan_obiwan_client_get_max_redirects*(obiwan_client: ObiwanClient): Natural {.raises: [], cdecl, exportc, dynlib.} =
  obiwan_client.maxRedirects

proc obiwan_obiwan_client_set_max_redirects*(obiwan_client: ObiwanClient, maxRedirects: Natural) {.raises: [], cdecl, exportc, dynlib.} =
  obiwan_client.maxRedirects = maxRedirects

proc obiwan_obiwan_client_request*(client: ObiwanClient, url: cstring): Response {.raises: [], cdecl, exportc, dynlib.} =
  request(client, url.`$`)

proc obiwan_obiwan_client_close*(client: ObiwanClient) {.raises: [], cdecl, exportc, dynlib.} =
  close(client)

proc obiwan_obiwan_server_unref*(x: ObiwanServer) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(x)

proc obiwan_new_obiwan_server*(reuse_addr: bool, reuse_port: bool, cert_file: cstring, key_file: cstring, session_id: cstring): ObiwanServer {.raises: [], cdecl, exportc, dynlib.} =
  newObiwanServer(reuse_addr, reuse_port, cert_file.`$`, key_file.`$`, session_id.`$`)

proc obiwan_obiwan_server_get_reuse_addr*(obiwan_server: ObiwanServer): bool {.raises: [], cdecl, exportc, dynlib.} =
  obiwan_server.reuseAddr

proc obiwan_obiwan_server_set_reuse_addr*(obiwan_server: ObiwanServer, reuseAddr: bool) {.raises: [], cdecl, exportc, dynlib.} =
  obiwan_server.reuseAddr = reuseAddr

proc obiwan_obiwan_server_get_reuse_port*(obiwan_server: ObiwanServer): bool {.raises: [], cdecl, exportc, dynlib.} =
  obiwan_server.reusePort

proc obiwan_obiwan_server_set_reuse_port*(obiwan_server: ObiwanServer, reusePort: bool) {.raises: [], cdecl, exportc, dynlib.} =
  obiwan_server.reusePort = reusePort

proc obiwan_response_unref*(x: Response) {.raises: [], cdecl, exportc, dynlib.} =
  GC_unref(x)

proc obiwan_response_get_status*(response: Response): Status {.raises: [], cdecl, exportc, dynlib.} =
  response.status

proc obiwan_response_set_status*(response: Response, status: Status) {.raises: [], cdecl, exportc, dynlib.} =
  response.status = status

proc obiwan_response_get_meta*(response: Response): cstring {.raises: [], cdecl, exportc, dynlib.} =
  response.meta.cstring

proc obiwan_response_set_meta*(response: Response, meta: cstring) {.raises: [], cdecl, exportc, dynlib.} =
  response.meta = meta.`$`

proc obiwan_response_body*(response: Response): cstring {.raises: [], cdecl, exportc, dynlib.} =
  body(response).cstring

proc obiwan_response_has_certificate*(transaction: Response): bool {.raises: [], cdecl, exportc, dynlib.} =
  hasCertificate(transaction)

proc obiwan_response_is_verified*(transaction: Response): bool {.raises: [], cdecl, exportc, dynlib.} =
  isVerified(transaction)

proc obiwan_response_is_self_signed*(transaction: Response): bool {.raises: [], cdecl, exportc, dynlib.} =
  isSelfSigned(transaction)

proc obiwan_check_error*(): bool {.raises: [], cdecl, exportc, dynlib.} =
  checkError()

proc obiwan_take_error*(): cstring {.raises: [], cdecl, exportc, dynlib.} =
  takeError().cstring

