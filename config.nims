switch("path", ".") # Module search path
switch("out", "build/")

# Platform detection
when defined(macosx):
  switch("define", "isMacOS")

# mbedTLS configuration (using vendored mbedTLS)
# Get the project root directory
import os
let projectRoot = getCurrentDir()
let mbedTLSRoot = projectRoot & "/vendor/mbedtls"

# Use the vendored mbedTLS instead of system one
switch("passC", "-I" & mbedTLSRoot & "/include")
switch("define", "useMbedTLS")

# Compile mbedTLS libraries and link statically
# This assumes we'll build the mbedTLS libraries separately
when defined(macosx):
  switch("passL", "-L" & mbedTLSRoot & "/library -Wl,-force_load " & 
    mbedTLSRoot & "/library/libmbedtls.a -Wl,-force_load " & 
    mbedTLSRoot & "/library/libmbedcrypto.a -Wl,-force_load " & 
    mbedTLSRoot & "/library/libmbedx509.a")
else:
  switch("passL", "-L" & mbedTLSRoot & "/library -Wl,--whole-archive " & 
    mbedTLSRoot & "/library/libmbedtls.a " & 
    mbedTLSRoot & "/library/libmbedcrypto.a " & 
    mbedTLSRoot & "/library/libmbedx509.a -Wl,--no-whole-archive")

# Optimization options
when defined(release):
  switch("opt", "size")       # Optimize for binary size over speed
  switch("passC", "-flto")    # Link-time optimization to remove unused code
  switch("passL", "-flto")    # Link-time optimization
  switch("gc", "arc")         # Nim's Arc garbage collector (more efficient than default)
  switch("define", "danger")  # Disables runtime checks
  switch("panics", "on")      # Use panic handler instead of exceptions
  #switch("strip", "on")      # Strips debug symbols
