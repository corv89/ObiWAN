switch("path", ".") # Module search path
switch("out", "build/")

# mbedTLS configuration (static linking) for MacOS
switch("passL", "-L/opt/homebrew/opt/mbedtls/lib -Wl,-force_load /opt/homebrew/opt/mbedtls/lib/libmbedtls.a -Wl,-force_load /opt/homebrew/opt/mbedtls/lib/libmbedcrypto.a -Wl,-force_load /opt/homebrew/opt/mbedtls/lib/libmbedx509.a")
switch("passC", "-I/opt/homebrew/opt/mbedtls/include")
switch("define", "useMbedTLS")

# Optimization options
when defined(release):
  switch("opt", "size")       # Optimize for binary size over speed
  switch("passC", "-flto")    # Link-time optimization to remove unused code
  switch("passL", "-flto")    # Link-time optimization
  switch("gc", "arc")         # Nim's Arc garbage collector (more efficient than default)
  switch("define", "danger")  # Disables runtime checks
  switch("panics", "on")      # Use panic handler instead of exceptions
  #switch("strip", "on")      # Strips debug symbols
