## URL handling for the ObiWAN Gemini protocol library
##
## This module provides URL parsing and manipulation functionality for
## Gemini protocol URLs, using the Webby library for robust URL handling.

import webby as wb
import std/uri
import std/strutils

# Type alias
type Url* = wb.Url
type QueryParams* = wb.QueryParams

# Re-export webby functions
export wb.paths, wb.encodeURIComponent, wb.decodeURIComponent
export wb.parseUrl, wb.parseSearch 
export wb.`[]`, wb.`[]=`, wb.contains, wb.getOrDefault, wb.add
export wb.`$`

proc toUri*(url: Url): Uri =
  ## Convert a Webby URL to a Nim standard library Uri
  ## This is useful for transitioning code while maintaining compatibility
  result = Uri(
    scheme: url.scheme,
    username: url.username,
    password: url.password,
    hostname: url.hostname,
    port: url.port,
    path: url.path,
    query: if url.query.len > 0: $url.query else: "",
    anchor: url.fragment
  )
  # Different structure in Webby vs Nim stdlb
  if url.opaque != "":
    result.path = url.opaque

proc fromUri*(uri: Uri): Url =
  ## Convert a Nim standard library Uri to a Webby URL
  ## This is useful for transitioning code while maintaining compatibility
  result = Url(
    scheme: uri.scheme,
    username: uri.username,
    password: uri.password,
    hostname: uri.hostname,
    port: uri.port,
    path: uri.path,
    fragment: uri.anchor
  )

  # Handle opaque URLs (scheme-relative)
  if uri.scheme != "" and not uri.path.startsWith('/') and uri.hostname == "":
    result.opaque = uri.path
    result.path = ""
  
  if uri.query.len > 0:
    result.query = wb.parseSearch(uri.query)

proc geminiPort*(url: Url): int =
  ## Get the port from a Gemini URL, defaulting to 1965 if not specified
  if url.port == "":
    return 1965
  else:
    return parseInt(url.port)

proc unbracketed*(hostname: string): string =
  ## Remove IPv6 brackets from hostname if present
  ## This is useful when passing a hostname to socket functions
  if hostname.startsWith('[') and hostname.endsWith(']') and hostname.len > 2:
    return hostname[1..^2]  # Remove first and last character (the brackets)
  return hostname

proc combineUrl*(baseUrl, target: Url): Url =
  ## Combine two URLs for handling relative redirects
  ## This is particularly useful for handling Gemini redirects
  if target.scheme != "":
    return target  # Target is absolute, return as is
  
  # Create a new URL using the base URL's components
  result = Url(
    scheme: baseUrl.scheme,
    username: baseUrl.username, 
    password: baseUrl.password,
    hostname: baseUrl.hostname,
    port: baseUrl.port
  )
  
  # Handle different path combinations
  if target.path.startsWith('/'):
    result.path = target.path  # Target path is absolute
  else:
    # Relative path - start with base path
    var basePath = baseUrl.path
    
    # If target has a path, construct the new path
    if target.path != "":
      # Remove file component from base path if it exists
      let lastSlash = basePath.rfind('/')
      if lastSlash >= 0:
        basePath = basePath[0..lastSlash]
      else:
        basePath = "/"
        
      result.path = basePath & target.path
    else:
      result.path = basePath
  
  # Copy query and fragment from target
  result.query = target.query
  result.fragment = target.fragment

proc validateGeminiUrl*(url: Url): bool =
  ## Validate that a URL is a valid Gemini URL
  ## Returns true if the URL is valid for Gemini usage
  
  # Gemini protocol requires the scheme to be "gemini"
  if url.scheme != "gemini":
    return false
    
  # Hostname is required for Gemini URLs
  if url.hostname == "":
    return false
    
  return true

proc parseGeminiUrl*(urlStr: string): Url =
  ## Parse a Gemini URL string into a URL object
  ## This handles Gemini-specific validation and defaults
  
  result = wb.parseUrl(urlStr)
  
  # Apply Gemini-specific defaults if needed
  if result.scheme == "" and result.hostname != "":
    result.scheme = "gemini"