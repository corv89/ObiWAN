## Synchronous Gemini Client implementation
## 
## This module provides a command-line synchronous (blocking) Gemini protocol client
## using the ObiWAN library. It demonstrates basic request/response handling,
## certificate verification, and content display.
##
## Usage:
##   ```
##   ./build/client [url] [cert_file] [key_file]
##   ```
## Where:
##   - url: The Gemini URL to request (defaults to "gemini://geminiprotocol.net/")
##   - cert_file: Optional path to client certificate for authentication
##   - key_file: Optional path to client private key for authentication
##
## Example:
##   ```
##   ./build/client gemini://example.com/ client-cert.pem client-key.pem
##   ```

import os
import "../../obiwan"

# Main application code
when isMainModule:
  # Parse command line arguments
  let
    url = if paramCount() >= 1: paramStr(1) else: "gemini://geminiprotocol.net/"
    certFile = if paramCount() >= 2: paramStr(2) else: ""
    keyFile = if paramCount() >= 3: paramStr(3) else: ""
  
  try:
    # Initialize client with optional certificate for client authentication
    echo "Creating client with mbedTLS..."
    let client = newObiwanClient(certFile=certFile, keyFile=keyFile)
    
    # Make request to the specified URL
    echo "Sending request to ", url
    let response = client.request(url)
    # Ensure proper cleanup when we're done
    defer: client.close()

    # Display response status and meta information
    echo "Status: " & $response.status
    echo "Meta: " & response.meta

    # Display certificate information (for TOFU verification)
    echo "Certificate info:"
    if response.certificate != nil:
      echo "  Certificate available"
      echo "  Is Verified: " & $response.isVerified
      echo "  Is Self-signed: " & $response.isSelfSigned
    else:
      echo "  No certificate available"

    # Display response body content
    echo "Response body:"
    echo response.body
  except:
    # Handle any errors that occurred during the request
    echo "Error: ", getCurrentExceptionMsg()
