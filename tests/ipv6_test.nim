import uri
import strformat

# Test IPv6 URL parsing
let urlStr = "gemini://[::1]/"
let url = parseUri(urlStr)

echo fmt"Original URL: {urlStr}"
echo fmt"Scheme: {url.scheme}"
echo fmt"Hostname: {url.hostname}"
echo fmt"Path: {url.path}"
