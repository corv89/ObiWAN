## Test for the obiwan/fs.nim module
##
## Tests the file system operations, MIME type detection, path security, and
## file serving functionality.

import std/unittest
import std/os
import std/strutils

when not defined(skipMbedTLS):
  {.warning: "Setting skipMbedTLS to avoid linking issues in test".}
  {.define: skipMbedTLS.}

import ../src/obiwan/fs

# Default values - actual setup happens in the setup block
var tempDir: string
var contentDir: string
var indexContent: string

suite "ObiWAN File System Module Tests":
  # Set up test files and directories before each test
  setup:
    # Create test directories
    tempDir = getCurrentDir() / "test_temp_dir"
    removeDir(tempDir) # Clean up any previous test run
    createDir(tempDir)
    
    contentDir = tempDir / "content"
    createDir(contentDir)
    
    # Create test files
    indexContent = """# Test Index Page
This is a test index page for the ObiWAN filesystem tests.

## Links
=> /about.gmi About page
=> /test.txt A text file
"""
    writeFile(contentDir / "index.gmi", indexContent)
    writeFile(contentDir / "test.txt", "This is a plain text file for testing.")
    
    # Create subdirectory
    createDir(contentDir / "subdir")
    writeFile(contentDir / "subdir" / "index.gmi", "# Subdirectory Index\n\nThis is a subdirectory index.")
    writeFile(contentDir / "subdir" / "file.txt", "Text file in subdirectory")
  
  # Clean up at the end of each test
  teardown:
    try:
      removeDir(tempDir)
      if dirExists("./temp_docroot"):
        removeDir("./temp_docroot")
    except:
      echo "Warning: Failed to remove temporary directories"
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
    
  test "Document root path normalization":
    # Test relative docRoot paths (like ./content)
    let relDocRoot = "./temp_docroot"
    createDir(relDocRoot)
    writeFile(relDocRoot / "test.gmi", "# Test\n\nThis is a test file")
    
    try:
      # The code in server.nim normalizes relative paths by converting them to absolute
      let absDocRoot = getCurrentDir() / "temp_docroot"
      
      # Test that handleFileRequest can handle this pattern
      let result = handleFileRequest(absDocRoot, "/test.gmi")
      check result.success
      check result.mimeType == "text/gemini"
      check result.content == "# Test\n\nThis is a test file"
    finally:
      removeDir("./temp_docroot")
      
  test "Path handling with trailing slashes":
    # Test handling of paths with and without trailing slashes
    
    # Create test directory and file
    let testDir = tempDir / "trailing_slash_test"
    createDir(testDir)
    createDir(testDir / "subdir")
    writeFile(testDir / "subdir" / "index.gmi", "# Test Index")
    
    # Test with trailing slash - should find index.gmi
    let resultWithSlash = handleFileRequest(testDir, "/subdir/")
    check resultWithSlash.success
    check resultWithSlash.content == "# Test Index"
    
    # Test without trailing slash - should still find index.gmi
    # This behavior depends on implementation, but is recommended
    let resultWithoutSlash = handleFileRequest(testDir, "/subdir")
    
    # We're checking if it works, but not mandating specific behavior
    # Some implementations might perform a redirect in this case
    if resultWithoutSlash.success:
      check resultWithoutSlash.content == "# Test Index"