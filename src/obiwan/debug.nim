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
  ## In release builds, this is a no-op.
  when not defined(release):
    echo msg

proc debugf*(format: string, args: varargs[string]) =
  ## Formats and logs a debug message.
  ## In release builds, this is a no-op.
  when not defined(release):
    # Use a simple replacement approach
    var result = format
    for arg in args:
      result = result.replace("{}", arg)
    echo result

template withDebug*(body: untyped) =
  ## Executes the given code block only in debug builds.
  when not defined(release):
    body
