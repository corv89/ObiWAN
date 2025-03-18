import ../src/obiwan
import ../src/obiwan/common

{.push raises: [].}

# Simple C-compatible data structures
type
  ObiwanClientHandle* = pointer
  ObiwanServerHandle* = pointer
  
  ObiwanResponseData* = object
    status*: cint
    meta*: cstring
    body*: cstring
    hasBody*: bool

# String handling helper
var stringCache: seq[string] = @[]

proc cacheString(s: string): cstring =
  stringCache.add(s)
  return stringCache[^1].cstring

# Client API
proc initObiwan*() {.exportc, dynlib.} =
  echo "Initializing ObiWAN"
  stringCache = @[]

proc createClient*(maxRedirects: cint, certFile, keyFile: cstring): ObiwanClientHandle {.exportc, dynlib.} =
  try:
    let client = newObiwanClient(int(maxRedirects), $certFile, $keyFile)
    GC_ref(client) # Add a reference to prevent GC
    return cast[ObiwanClientHandle](client)
  except:
    return nil

proc destroyClient*(client: ObiwanClientHandle) {.exportc, dynlib.} =
  try:
    if client.isNil:
      return
    let obiwanClient = cast[ObiwanClient](client)
    obiwanClient.close()
    GC_unref(obiwanClient) # Remove the reference
  except:
    discard

proc requestUrl*(client: ObiwanClientHandle, url: cstring, response: ptr ObiwanResponseData): cint {.exportc, dynlib.} =
  try:
    if client.isNil:
      return -1
    
    let obiwanClient = cast[ObiwanClient](client)
    let resp = obiwanClient.request($url)
    
    response.status = cint(resp.status.int)
    response.meta = cacheString(resp.meta)
    
    if resp.status == Status.Success:
      let bodyContent = resp.body()
      response.body = cacheString(bodyContent)
      response.hasBody = true
    else:
      response.body = nil
      response.hasBody = false
    
    return 0
  except:
    return -1

# Server API
proc createServer*(reuseAddr: bool, reusePort: bool, certFile, keyFile, sessionId: cstring): ObiwanServerHandle {.exportc, dynlib.} =
  try:
    let server = newObiwanServer(reuseAddr, reusePort, $certFile, $keyFile, $sessionId)
    GC_ref(server) # Add a reference to prevent GC
    return cast[ObiwanServerHandle](server)
  except:
    return nil

proc destroyServer*(server: ObiwanServerHandle) {.exportc, dynlib.} =
  try:
    if server.isNil:
      return
    let obiwanServer = cast[ObiwanServer](server)
    GC_unref(obiwanServer) # Remove the reference
  except:
    discard

{.pop.}