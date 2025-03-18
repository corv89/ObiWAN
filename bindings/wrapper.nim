import ../src/obiwan
import ../src/obiwan/common

{.push raises: [].}

# Simple C-compatible data structures
type
  ObiwanClientHandle* = pointer
  ObiwanServerHandle* = pointer
  ObiwanResponseHandle* = pointer

  ObiwanResponseData* = object
    status*: cint
    meta*: cstring
    body*: cstring
    hasBody*: bool
    hasCertificate*: bool
    isVerified*: bool
    isSelfSigned*: bool

# Error handling
var lastError: string = ""

proc setError(msg: string) =
  lastError = msg

# String handling helper
var stringCache: seq[string] = @[]

proc cacheString(s: string): cstring =
  stringCache.add(s)
  return stringCache[^1].cstring

# Client API
proc initObiwan*() {.exportc: "initObiwan", dynlib.} =
  echo "Initializing ObiWAN"
  stringCache = @[]
  lastError = ""

proc hasError*(): bool {.exportc: "hasError", dynlib.} =
  return lastError.len > 0

proc getLastError*(): cstring {.exportc: "getLastError", dynlib.} =
  if lastError.len > 0:
    let error = lastError
    lastError = ""
    return cacheString(error)
  return nil

proc createClient*(maxRedirects: cint, certFile,
    keyFile: cstring): ObiwanClientHandle {.exportc: "createClient", dynlib.} =
  try:
    let client = newObiwanClient(int(maxRedirects), $certFile, $keyFile)
    GC_ref(client) # Add a reference to prevent GC
    return cast[ObiwanClientHandle](client)
  except ObiwanError as e:
    setError("ObiwanError: " & e.msg)
    return nil
  except MbedtlsError as e:
    setError("MbedtlsError: " & e.msg)
    return nil
  except:
    setError("Unknown error during client creation")
    return nil

proc destroyClient*(client: ObiwanClientHandle) {.exportc: "destroyClient", dynlib.} =
  try:
    if client.isNil:
      return
    let obiwanClient = cast[ObiwanClient](client)
    obiwanClient.close()
    GC_unref(obiwanClient) # Remove the reference
  except:
    setError("Error destroying client")

# Response handling
proc requestUrl*(client: ObiwanClientHandle,
    url: cstring): ObiwanResponseHandle {.exportc: "requestUrl", dynlib.} =
  try:
    if client.isNil:
      setError("Client is nil")
      return nil

    let obiwanClient = cast[ObiwanClient](client)
    let resp = obiwanClient.request($url)
    GC_ref(resp) # Add a reference to prevent GC
    return cast[ObiwanResponseHandle](resp)
  except ObiwanError as e:
    setError("ObiwanError: " & e.msg)
    return nil
  except MbedtlsError as e:
    setError("MbedtlsError: " & e.msg)
    return nil
  except:
    setError("Unknown error during request")
    return nil

proc destroyResponse*(response: ObiwanResponseHandle) {.exportc: "destroyResponse", dynlib.} =
  try:
    if response.isNil:
      return
    let resp = cast[Response](response)
    GC_unref(resp) # Remove the reference
  except:
    setError("Error destroying response")

proc getResponseStatus*(response: ObiwanResponseHandle): cint {.exportc: "getResponseStatus", dynlib.} =
  try:
    if response.isNil:
      setError("Response is nil")
      return -1
    let resp = cast[Response](response)
    return cint(resp.status.int)
  except:
    setError("Error getting response status")
    return -1

proc getResponseMeta*(response: ObiwanResponseHandle): cstring {.exportc: "getResponseMeta", dynlib.} =
  try:
    if response.isNil:
      setError("Response is nil")
      return nil
    let resp = cast[Response](response)
    return cacheString(resp.meta)
  except:
    setError("Error getting response meta")
    return nil

proc getResponseBody*(response: ObiwanResponseHandle): cstring {.exportc: "getResponseBody", dynlib.} =
  try:
    if response.isNil:
      setError("Response is nil")
      return nil
    let resp = cast[Response](response)
    if resp.status == Status.Success:
      return cacheString(resp.body())
    return nil
  except ObiwanError as e:
    setError("ObiwanError: " & e.msg)
    return nil
  except:
    setError("Error getting response body")
    return nil

proc responseHasCertificate*(response: ObiwanResponseHandle): bool {.exportc: "responseHasCertificate", dynlib.} =
  try:
    if response.isNil:
      setError("Response is nil")
      return false
    let resp = cast[Response](response)
    return resp.hasCertificate()
  except:
    setError("Error checking certificate presence")
    return false

proc responseIsVerified*(response: ObiwanResponseHandle): bool {.exportc: "responseIsVerified", dynlib.} =
  try:
    if response.isNil:
      setError("Response is nil")
      return false
    let resp = cast[Response](response)
    return resp.isVerified()
  except:
    setError("Error checking certificate verification")
    return false

proc responseIsSelfSigned*(response: ObiwanResponseHandle): bool {.exportc: "responseIsSelfSigned", dynlib.} =
  try:
    if response.isNil:
      setError("Response is nil")
      return false
    let resp = cast[Response](response)
    return resp.isSelfSigned()
  except:
    setError("Error checking if certificate is self-signed")
    return false

# Server API
proc createServer*(reuseAddr: bool, reusePort: bool, certFile, keyFile,
    sessionId: cstring): ObiwanServerHandle {.exportc: "createServer", dynlib.} =
  try:
    let server = newObiwanServer(reuseAddr, reusePort, $certFile, $keyFile, $sessionId)
    GC_ref(server) # Add a reference to prevent GC
    return cast[ObiwanServerHandle](server)
  except ObiwanError as e:
    setError("ObiwanError: " & e.msg)
    return nil
  except MbedtlsError as e:
    setError("MbedtlsError: " & e.msg)
    return nil
  except:
    setError("Unknown error during server creation")
    return nil

proc destroyServer*(server: ObiwanServerHandle) {.exportc: "destroyServer", dynlib.} =
  try:
    if server.isNil:
      return
    let obiwanServer = cast[ObiwanServer](server)
    GC_unref(obiwanServer) # Remove the reference
  except:
    setError("Error destroying server")

{.pop.}
