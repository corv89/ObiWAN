## Synchronous Gemini Client implementation
## 
## This module provides a command-line synchronous (blocking) Gemini protocol client
## using the ObiWAN library. It supports configuration via TOML files
## for easier setup and maintenance.
##
## Usage:
##   ```
##   ./build/client [url] [config_file]
##   ```
## Where:
##   - url: The Gemini URL to request (defaults to "gemini://geminiprotocol.net/")
##   - config_file: Optional path to TOML configuration file
##
## Configuration is loaded from:
## 1. The specified config file or
## 2. ./obiwan.toml (current directory) or
## 3. ~/.config/obiwan/config.toml (user config) or
## 4. /etc/obiwan/config.toml (system config)
## 5. Default values if no config file is found
##
## To use client certificates, specify them in the config file:
## ```toml
## [client]
## cert_file = "client-cert.pem"
## key_file = "client-key.pem"
## ```

import os
import "../../obiwan"
import "../config"

# Main application code
when isMainModule:
  # Parse command line arguments
  let
    url = if paramCount() >= 1: paramStr(1) else: "gemini://geminiprotocol.net/"
    configPath = if paramCount() >= 2: paramStr(2) else: ""

  try:
    # Load configuration
    var config = loadOrCreateConfig(configPath)
    
    # Initialize logging
    initializeLogging(config)
    
    # Output startup information
    echo "ObiWAN Gemini Client"
    echo "==================="
    
    # Show config path if available, otherwise indicate default config
    if resolveConfigFile(configPath) != "":
      echo "Using configuration from: ", resolveConfigFile(configPath)
    else:
      echo "Using default configuration"
    
    # Show client settings
    echo "Client settings:"
    echo "  Max redirects: ", config.client.maxRedirects
    if config.client.certFile != "":
      echo "  Client cert:   ", config.client.certFile
      echo "  Client key:    ", config.client.keyFile
    else:
      echo "  Client cert:   none"
      
    # Initialize client with certificate from config
    echo "\nRequesting URL: ", url
    let client = newObiwanClient(
      maxRedirects = config.client.maxRedirects,
      certFile = config.client.certFile,
      keyFile = config.client.keyFile
    )
    
    # Make request to the specified URL
    let response = client.request(url)
    # Ensure proper cleanup when we're done
    defer: client.close()

    # Display response status and meta information
    echo "\nResponse:"
    echo "  Status: " & $response.status & " (" & $response.status.int & ")"
    echo "  Meta:   " & response.meta

    # Display certificate information (for TOFU verification)
    echo "\nCertificate info:"
    if response.certificate != nil:
      echo "  Certificate available"
      echo "  Is Verified:    " & $response.isVerified
      echo "  Is Self-signed: " & $response.isSelfSigned
    else:
      echo "  No certificate available"

    # Display response body content
    echo "\nResponse body:"
    echo response.body
  except CatchableError:
    # Handle any errors that occurred during the request
    echo "Error: ", getCurrentExceptionMsg()