# Debug utilities
#
# This module provides debug logging that is automatically disabled in release builds
import strutils

when not defined(release):
  const debugEnabled* = true
else:
  const debugEnabled* = false

proc debug*(msg: string) =
  ## Logs a debug message to stdout.
  ##
  ## This procedure outputs debug information during development and testing.
  ## All debug output is automatically disabled in release builds, with no
  ## runtime overhead.
  ##
  ## Parameters:
  ##   msg: The debug message to output
  ##
  ## Example:
  ##   ```nim
  ##   debug("Connecting to server...")
  ##   ```
  when not defined(release):
    echo msg

proc debugf*(format: string, args: varargs[string]) =
  ## Formats and logs a debug message with placeholders.
  ##
  ## This procedure allows formatted debug output with string interpolation
  ## using "{}" placeholders. All debug output is automatically disabled in 
  ## release builds, with no runtime overhead.
  ##
  ## Parameters:
  ##   format: The format string with "{}" placeholders
  ##   args: The string arguments to substitute into the placeholders
  ##
  ## Example:
  ##   ```nim
  ##   debugf("Connecting to {}:{}", serverName, $port)
  ##   ```
  when not defined(release):
    # Use a simple replacement approach
    var result = format
    for arg in args:
      result = result.replace("{}", arg)
    echo result

template withDebug*(body: untyped) =
  ## Executes the given code block only in debug builds.
  ##
  ## This template allows conditional compilation of debugging code
  ## that will be completely eliminated in release builds. Use this
  ## for more complex debugging operations that might have overhead.
  ##
  ## Example:
  ##   ```nim
  ##   withDebug:
  ##     let elapsed = epochTime() - startTime
  ##     echo "Operation took ", elapsed, " seconds"
  ##   ```
  when not defined(release):
    body
