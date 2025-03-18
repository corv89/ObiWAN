# Debug utilities
#
# This module provides debug logging that is automatically disabled in release builds
when not defined(release):
  import strutils

when not defined(release):
  const debugEnabled* = true
else:
  const debugEnabled* = false

# Default verbosity level
# 0 = Critical only
# 1 = Errors and critical 
# 2 = Warnings, errors, and critical
# 3 = Info, warnings, errors, and critical
# 4 = Debug, info, warnings, errors, and critical
var verbosityLevel* = 3

proc setVerbosityLevel*(level: int) =
  ## Sets the verbosity level for debug output.
  ##
  ## Parameters:
  ##   level: The verbosity level (0-4)
  ##     0 = Critical only
  ##     1 = Errors and critical
  ##     2 = Warnings, errors, and critical
  ##     3 = Info, warnings, errors, and critical (default)
  ##     4 = Debug, info, warnings, errors, and critical
  verbosityLevel = max(0, min(level, 4))

proc debug*(msg: string, level: int = 4) =
  ## Logs a debug message to stdout if the verbosity level is high enough.
  ##
  ## This procedure outputs debug information during development and testing.
  ## All debug output is automatically disabled in release builds, with no
  ## runtime overhead.
  ##
  ## Parameters:
  ##   msg: The debug message to output
  ##   level: The verbosity level of this message (0-4)
  ##
  ## Example:
  ##   ```nim
  ##   debug("Connecting to server...", 3) # Only shown at verbosity 3+
  ##   ```
  when not defined(release):
    if level <= verbosityLevel:
      echo msg

proc debugf*(format: string, args: varargs[string], level: int = 4) =
  ## Formats and logs a debug message with placeholders if the verbosity level is high enough.
  ##
  ## This procedure allows formatted debug output with string interpolation
  ## using "{}" placeholders. All debug output is automatically disabled in 
  ## release builds, with no runtime overhead.
  ##
  ## Parameters:
  ##   format: The format string with "{}" placeholders
  ##   args: The string arguments to substitute into the placeholders
  ##   level: The verbosity level of this message (0-4)
  ##
  ## Example:
  ##   ```nim
  ##   debugf("Connecting to {}:{}", serverName, $port, 2) # Only shown at verbosity 2+
  ##   ```
  when not defined(release):
    if level <= verbosityLevel:
      # Use a simple replacement approach
      var result = format
      for arg in args:
        result = result.replace("{}", arg)
      echo result

proc critical*(msg: string) = debug(msg, 0)
proc error*(msg: string) = debug(msg, 1)
proc warning*(msg: string) = debug(msg, 2)
proc info*(msg: string) = debug(msg, 3)

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
