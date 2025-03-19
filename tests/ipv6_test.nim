import obiwan/url
import strformat

# Test IPv6 URL parsing
let urlStr = "gemini://[::1]/"
let url = parseUrl(urlStr)

echo fmt"Original URL: {urlStr}"
echo fmt"Scheme: {url.scheme}"
echo fmt"Hostname: {url.hostname} (with brackets)"
echo fmt"Path: {url.path}"
