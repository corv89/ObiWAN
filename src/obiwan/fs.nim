## ObiWAN File System Module
##
## This module provides filesystem operations for serving Gemini content,
## including file handling, MIME type detection, and security measures.

import std/os
import std/strutils
import std/tables
import std/algorithm # For sort
import webby as wb

# MIME type mapping based on file extensions
const mimeTypes = {
  # Gemini-specific
  ".gmi": "text/gemini",
  ".gemini": "text/gemini",
  
  # Text formats
  ".txt": "text/plain",
  ".md": "text/markdown",
  ".markdown": "text/markdown",
  ".html": "text/html",
  ".htm": "text/html",
  ".css": "text/css",
  ".csv": "text/csv",
  
  # Images
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".png": "image/png",
  ".gif": "image/gif",
  ".svg": "image/svg+xml",
  ".webp": "image/webp",
  
  # Audio
  ".mp3": "audio/mpeg",
  ".wav": "audio/wav",
  ".ogg": "audio/ogg",
  
  # Video
  ".mp4": "video/mp4",
  ".webm": "video/webm",
  
  # Documents
  ".pdf": "application/pdf",
  
  # Archives
  ".zip": "application/zip",
  ".gz": "application/gzip",
  
  # Other
  ".json": "application/json",
  ".xml": "application/xml",
}.toTable()

type
  FileSecurityError* = object of CatchableError
    ## Exception raised for file security violations

proc detectMimeType*(filePath: string): string =
  ## Detects MIME type based on file extension
  ##
  ## Parameters:
  ##   filePath: Path to the file
  ##
  ## Returns:
  ##   MIME type as a string, defaults to "application/octet-stream" if unknown
  
  let ext = filePath.splitFile.ext.toLowerAscii()
  if ext in mimeTypes:
    return mimeTypes[ext]
  
  # Default to binary if unknown
  return "application/octet-stream"

proc sanitizePath*(basePath, reqPath: string): string =
  ## Sanitizes a request path to prevent directory traversal attacks
  ##
  ## Parameters:
  ##   basePath: The base directory (docRoot)
  ##   reqPath: The request path to sanitize
  ##
  ## Returns:
  ##   The sanitized absolute path
  ##
  ## Raises:
  ##   FileSecurityError: If path traversal is detected
  
  # Decode URL path (handle percent encoding)
  var path = wb.decodeURIComponent(reqPath)
  
  # Remove leading slash if present
  if path.startsWith("/"):
    path = path[1..^1]
  
  # Normalize the path (resolve . and ..)
  var normalizedParts: seq[string] = @[]
  
  for part in path.split('/'):
    if part == "..":
      if normalizedParts.len > 0:
        discard normalizedParts.pop()
      else:
        # Trying to go above the root directory - security violation
        raise newException(FileSecurityError, "Path traversal detected")
    elif part == "." or part == "":
      # Skip . and empty parts
      continue
    else:
      normalizedParts.add(part)
  
  # Join the path with OS-specific separator
  var resultPath = basePath
  for part in normalizedParts:
    resultPath = resultPath / part
  
  # Verify the final path is still within the base path
  if not resultPath.startsWith(basePath):
    raise newException(FileSecurityError, "Path traversal detected")
  
  return resultPath

proc readFileContents*(filePath: string): tuple[content: string, size: int64] =
  ## Reads a file's contents and returns them with the file size
  ##
  ## Parameters:
  ##   filePath: Path to the file to read
  ##
  ## Returns:
  ##   Tuple containing the file content and size
  ##
  ## Raises:
  ##   IOError: If the file cannot be read
  
  let fileSize = getFileSize(filePath)
  let content = readFile(filePath)
  
  return (content: content, size: fileSize)

proc isDirectoryListingAllowed*(basePath: string): bool =
  ## Checks if directory listing is allowed for the given path
  ##
  ## This could be expanded to check for a .noindex file or other indicators
  ##
  ## Parameters:
  ##   basePath: The directory path to check
  ##
  ## Returns:
  ##   True if directory listing is allowed, false otherwise
  
  # TODO: Implement more sophisticated logic based on configuration
  # For now, we'll allow all directory listings
  return true

proc generateDirectoryListing*(dirPath, requestPath: string): string =
  ## Generates a Gemini-formatted directory listing
  ##
  ## Parameters:
  ##   dirPath: The actual filesystem path to the directory
  ##   requestPath: The URL path that was requested (for links)
  ##
  ## Returns:
  ##   Gemini-formatted text for the directory listing
  
  result = "# Directory listing for " & requestPath & "\n\n"
  
  # Ensure request path ends with a slash for proper link construction
  var urlPath = requestPath
  if not urlPath.endsWith("/"):
    urlPath &= "/"
  
  # Add parent directory link unless we're at the root
  if urlPath != "/":
    result &= "=> .. Parent Directory\n\n"
  
  # First list directories
  var dirs: seq[string] = @[]
  var files: seq[string] = @[]
  
  for kind, path in walkDir(dirPath):
    let name = path.extractFilename
    
    # Skip hidden files
    if name.startsWith("."):
      continue
      
    if kind == pcDir:
      dirs.add(name)
    else:
      files.add(name)
  
  # Sort alphabetically
  dirs.sort()
  files.sort()
  
  # Add directories with trailing slash
  if dirs.len > 0:
    result &= "## Directories\n\n"
    for dir in dirs:
      result &= "=> " & urlPath & dir & "/ " & dir & "/\n"
    result &= "\n"
  
  # Add files
  if files.len > 0:
    result &= "## Files\n\n"
    for file in files:
      result &= "=> " & urlPath & file & " " & file & "\n"
  
  return result

proc handleFileRequest*(basePath, reqPath: string): tuple[content: string, mimeType: string, success: bool, errorMsg: string] =
  ## Handles a file request, returning the content and MIME type
  ##
  ## Parameters:
  ##   basePath: The base directory (docRoot)
  ##   reqPath: The request path
  ##
  ## Returns:
  ##   Tuple containing:
  ##   - content: File content or directory listing
  ##   - mimeType: MIME type of the content
  ##   - success: Whether the request was successful
  ##   - errorMsg: Error message if success is false
  
  try:
    let fullPath = sanitizePath(basePath, reqPath)
    
    # Check if path exists
    if not fileExists(fullPath) and not dirExists(fullPath):
      return (content: "", mimeType: "", success: false, errorMsg: "File not found")
    
    # Handle directory
    if dirExists(fullPath):
      # Check for index.gmi
      let indexPath = fullPath / "index.gmi"
      if fileExists(indexPath):
        let (content, _) = readFileContents(indexPath)
        return (content: content, mimeType: "text/gemini", success: true, errorMsg: "")
      
      # No index file, check if directory listing is allowed
      if isDirectoryListingAllowed(fullPath):
        let listing = generateDirectoryListing(fullPath, reqPath)
        return (content: listing, mimeType: "text/gemini", success: true, errorMsg: "")
      else:
        return (content: "", mimeType: "", success: false, errorMsg: "Directory listing not allowed")
    
    # Handle file
    let (content, _) = readFileContents(fullPath)
    let mimeType = detectMimeType(fullPath)
    
    return (content: content, mimeType: mimeType, success: true, errorMsg: "")
    
  except FileSecurityError:
    return (content: "", mimeType: "", success: false, errorMsg: "Security violation: Path traversal attempt")
  except IOError:
    return (content: "", mimeType: "", success: false, errorMsg: "Error reading file")
  except:
    return (content: "", mimeType: "", success: false, errorMsg: "Unknown error: " & getCurrentExceptionMsg())