## Asynchronous Gemini Client implementation
## 
## This module provides a command-line asynchronous (non-blocking) Gemini protocol client
## using the ObiWAN library. It supports configuration via TOML files
## for easier setup and maintenance.
##
## Usage:
##   async_client [options] [<url>]
##
## Options:
##   -h --help               Show this help screen
##   -v --verbose            Increase verbosity level
##   -c --config=<file>      Use specific config file
##   -r --redirects=<num>    Maximum number of redirects [default: 5]
##   --cert=<file>           Client certificate file for authentication
##   --key=<file>            Client key file for authentication
##   --version               Show version information
##
## Arguments:
##   <url>                   URL to request [default: gemini://geminiprotocol.net/]
##
## Configuration is loaded from (in order):
## 1. The specified config file with --config
## 2. ./obiwan.toml (current directory)
## 3. ~/.config/obiwan/config.toml (user config)
## 4. /etc/obiwan/config.toml (system config)
## 5. Default values if no config file is found
##
## Client certificates can be specified via command line (--cert and --key)
## or in the config file:
## ```toml
## [client]
## cert_file = "client-cert.pem"
## key_file = "client-key.pem"
## ```

import asyncdispatch
import os
import strutils
import "../../obiwan"
import "../config"
import docopt

const doc = """
ObiWAN Async Gemini Client

Usage:
  async_client [options] [<url>]

Options:
  -h --help               Show this help screen
  -v --verbose            Increase verbosity level
  -c --config=<file>      Use specific config file
  -r --redirects=<num>    Maximum number of redirects [default: 5]
  --cert=<file>           Client certificate file for authentication
  --key=<file>            Client key file for authentication
  --version               Show version information

Arguments:
  <url>                   URL to request [default: gemini://geminiprotocol.net/]
"""

const version = "ObiWAN Async Gemini Client v0.5.0"

proc main() {.async.} =
  ## Main asynchronous function that performs the Gemini request and displays results.
  
  # Parse command line arguments with docopt
  let args = docopt(doc, version=version)
  
  # Get configuration file path from arguments
  let configPath = if args["--config"]: $args["--config"] else: ""
  
  # Get URL from arguments
  let url = if args["<url>"]: $args["<url>"] else: "gemini://geminiprotocol.net/"

  try:
    # Load configuration
    var config = loadOrCreateConfig(configPath)
    
    # Override configuration with command line arguments
    if args["--verbose"]:
      config.log.level = 2  # Increase verbosity
    
    if args["--redirects"]:
      try:
        config.client.maxRedirects = parseInt($args["--redirects"])
      except ValueError:
        echo "Warning: Invalid redirect count, using default"
    
    # Certificate settings override from command line
    if args["--cert"]:
      config.client.certFile = $args["--cert"]
    
    if args["--key"]:
      config.client.keyFile = $args["--key"]
    
    # Initialize logging
    initializeLogging(config)
    
    # Output startup information
    echo "ObiWAN Async Gemini Client"
    echo "========================="
    
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
    let client = newAsyncObiwanClient(
      maxRedirects = config.client.maxRedirects,
      certFile = config.client.certFile,
      keyFile = config.client.keyFile
    )
    
    # Make request to the specified URL
    let response = await client.request(url)
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
    echo await response.body
  except CatchableError:
    # Handle any errors that occurred during the request
    echo "Error: ", getCurrentExceptionMsg()

# Main application code
when isMainModule:
  # Run the main async procedure with the event loop
  waitFor main()