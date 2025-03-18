import genny
import ../src/obiwan
import ../src/obiwan/common

# Error handling like in the Genny example
var lastError: ref ObiwanError

proc takeError(): string =
  result = lastError.msg
  lastError = nil

proc checkError(): bool =
  result = lastError != nil

# Hack to allow exceptions in export
{.push raises: [Defect, ObiwanError, MbedtlsError].}

# Define our enums to export
exportEnums:
  Status

# Export the ObiwanClient object
exportRefObject ObiwanClient:
  fields:
    maxRedirects
  constructor:
    newObiwanClient(int, string, string)
  procs:
    request(ObiwanClient, string)
    close(ObiwanClient)

# Export the ObiwanServer object
exportRefObject ObiwanServer:
  fields:
    reuseAddr
    reusePort
  constructor:
    newObiwanServer(bool, bool, string, string, string)
  # Server API methods would go here if implemented

# Export the Response type
exportRefObject Response:
  fields:
    status
    meta
  procs:
    body(Response)
    hasCertificate(Response)
    isVerified(Response)
    isSelfSigned(Response)

# Export helper functions
exportProcs:
  checkError
  takeError

# Generate bindings
writeFiles("bindings/generated", "obiwan")
include generated/internal

{.pop.}