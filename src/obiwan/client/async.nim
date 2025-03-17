## Asynchronous Gemini Client implementation
## 
## This module provides a command-line asynchronous (non-blocking) Gemini protocol client
## using the ObiWAN library and Nim's asyncdispatch module. It demonstrates non-blocking 
## request/response handling, certificate verification, and content display.
##
## Usage:
##   ```
##   ./build/async_client [url] [cert_file] [key_file]
##   ```
## Where:
##   - url: The Gemini URL to request (defaults to "gemini://geminiprotocol.net/")
##   - cert_file: Optional path to client certificate for authentication
##   - key_file: Optional path to client private key for authentication
##
## Example:
##   ```
##   ./build/async_client gemini://example.com/ client-cert.pem client-key.pem
##   ```

import asyncdispatch
import os
import strutils

import "../../obiwan"

proc main() {.async.} =
  ## Main asynchronous function that performs the Gemini request and displays results.
  ##
  ## This function:
  ## 1. Creates an async Gemini client
  ## 2. Makes a non-blocking request to the specified URL
  ## 3. Displays response information including status, headers, and certificate details
  ## 4. Retrieves and displays the response body asynchronously
  ##
  ## It demonstrates proper async/await usage for non-blocking network operations.
  
  # Parse command line arguments
  let
    url = if paramCount() >= 1: paramStr(1) else: "gemini://geminiprotocol.net/"
    certFile = if paramCount() >= 2: paramStr(2) else: ""
    keyFile = if paramCount() >= 3: paramStr(3) else: ""
  
  try:
    # Initialize async client with optional certificate for client authentication
    let client = newAsyncObiwanClient(certFile=certFile, keyFile=keyFile)
    
    # Make async request to the specified URL
    let response = await client.request(url)
    # Ensure proper cleanup when we're done
    defer: client.close()

    # Display response status and meta information
    echo "Status: " & $response.status
    echo "Meta: " & response.meta
    
    # Display certificate information (for TOFU verification)
    echo "Server certificate:"
    if response.certificate != nil:
      echo "  Certificate available"
      echo "  Is Verified: " & $response.isVerified
      echo "  Is Self-signed: " & $response.isSelfSigned
    else:
      echo "  No certificate available"

    # Asynchronously retrieve and display the response body
    echo "Body: " & await response.body
  except:
    # Handle any errors that occurred during the async request
    echo getCurrentExceptionMsg()

# Main application code
when isMainModule:
  # Run the main async procedure with the event loop
  waitFor main()
