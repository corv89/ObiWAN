## Test for the obiwan/fs.nim module
##
## Tests the file system operations, MIME type detection, path security, and
## file serving functionality.

import std/unittest
import std/os
import std/strutils
import std/tempfiles

when not defined(skipMbedTLS):
  {.warning: "Setting skipMbedTLS to avoid linking issues in test".}
  {.define: skipMbedTLS.}

import ../src/obiwan/fs

# Create a temporary directory for testing
let tempDir = createTempDir("obiwan_fs_test", "")

# Setup test files and directories
let contentDir = tempDir / "content"
createDir(contentDir)

# Create index.gmi
let indexContent = """# Test Index Page
This is a test index page for the ObiWAN filesystem tests.

## Links
=> /about.gmi About page
=> /test.txt A text file
"""
writeFile(contentDir / "index.gmi", indexContent)

# Create a text file
writeFile(contentDir / "test.txt", "This is a plain text file for testing.")

# Create a subdirectory
createDir(contentDir / "subdir")
writeFile(contentDir / "subdir" / "index.gmi", "# Subdirectory Index\n\nThis is a subdirectory index.")
writeFile(contentDir / "subdir" / "file.txt", "Text file in subdirectory")

suite "ObiWAN File System Module Tests":
  # Clean up at the end
  teardown:
    removeDir(tempDir)
  test "MIME type detection":
    check detectMimeType("test.gmi") == "text/gemini"
    check detectMimeType("test.txt") == "text/plain"
    check detectMimeType("test.jpg") == "image/jpeg"
    check detectMimeType("test.pdf") == "application/pdf"
    check detectMimeType("test.unknown") == "application/octet-stream"
  
  test "Path sanitization and security":
    # Normal path
    check sanitizePath(contentDir, "/test.txt") == contentDir / "test.txt"
    check sanitizePath(contentDir, "/subdir/file.txt") == contentDir / "subdir" / "file.txt"
    
    # Path with dot segments
    check sanitizePath(contentDir, "/subdir/../test.txt") == contentDir / "test.txt"
    
    # URLs with encoded characters
    check sanitizePath(contentDir, "/subdir/%66%69le.txt") == contentDir / "subdir" / "file.txt"
    
    # Try path traversal attack
    expect(FileSecurityError):
      discard sanitizePath(contentDir, "/../outside.txt")
    
    expect(FileSecurityError):
      discard sanitizePath(contentDir, "/subdir/../../outside.txt")
  
  test "File contents reading":
    let (content, size) = readFileContents(contentDir / "test.txt")
    check content == "This is a plain text file for testing."
    check size == len("This is a plain text file for testing.")
  
  test "Directory listing generation":
    let listing = generateDirectoryListing(contentDir, "/")
    check listing.contains("# Directory listing for /")
    check listing.contains("=> /index.gmi index.gmi")
    check listing.contains("=> /subdir/ subdir/")
    check listing.contains("=> /test.txt test.txt")
  
  test "File request handling - index file":
    let result = handleFileRequest(contentDir, "/")
    check result.success
    check result.mimeType == "text/gemini"
    check result.content == indexContent
  
  test "File request handling - regular file":
    let result = handleFileRequest(contentDir, "/test.txt")
    check result.success
    check result.mimeType == "text/plain"
    check result.content == "This is a plain text file for testing."
  
  test "File request handling - subdirectory index":
    let result = handleFileRequest(contentDir, "/subdir/")
    check result.success
    check result.mimeType == "text/gemini"
    check result.content == "# Subdirectory Index\n\nThis is a subdirectory index."
  
  test "File request handling - directory listing":
    # Remove the index file to test directory listing
    removeFile(contentDir / "index.gmi")
    let result = handleFileRequest(contentDir, "/")
    check result.success
    check result.mimeType == "text/gemini"
    check result.content.contains("# Directory listing for /")
    
    # Put index back for other tests
    writeFile(contentDir / "index.gmi", indexContent)
  
  test "File request handling - file not found":
    let result = handleFileRequest(contentDir, "/nonexistent.txt")
    check not result.success
    check result.errorMsg == "File not found"
  
  test "File request handling - path traversal attempt":
    let result = handleFileRequest(contentDir, "/../outside.txt")
    check not result.success
    check result.errorMsg == "Security violation: Path traversal attempt"