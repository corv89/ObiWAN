import genny
import ../src/obiwan
import ../src/obiwan/common

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

# Export the ObiwanServer object
exportRefObject ObiwanServer:
  fields:
    reuseAddr
    reusePort
  constructor:
    newObiwanServer(bool, bool, string, string, string)

# Generate bindings
writeFiles("bindings/generated", "obiwan")
include generated/internal

{.pop.}