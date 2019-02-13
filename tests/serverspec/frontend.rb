# test websecmap frontend application
describe docker_container('websecmap-frontend') do
  it { should exist }
end

# HTTP request to frontend
describe command('curl -sSvk https://faalkaart.test') do
  # should return successful
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
  # render complete page
  its(:stdout) {should contain('MSPAINT')}
  # HSTS security should be enabled
  its(:stderr) {should contain('Strict-Transport-Security: max-age=31536000; includeSubdomains')}
end

# same for IPv6
describe command('curl -6 -sSvk https://faalkaart.test') do
  # should return successful
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
  # render complete page
  its(:stdout) {should contain('MSPAINT')}
  # HSTS security should be enabled
  its(:stderr) {should contain('Strict-Transport-Security: max-age=31536000; includeSubdomains')}
end

# test some API calls
describe command('curl --compressed -sSvk "https://faalkaart.test/data/stats/NL/municipality/0"') do
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
end

# stats have explicit cache which is different from the webserver 10 minute default
# implicitly tests database migrations as it will return 500 if they are not applied
describe command('curl -sSvk "https://faalkaart.test/data/terrible_urls/NL/municipality/0"') do
  # should redirect www to no-www
  its(:stderr) {should contain('Cache-Control: max-age=86400')}
end

# all responses should be compressed
# proxied html
describe command('curl --compressed -sSvk "https://faalkaart.test/"') do
  its(:stderr) {should contain('Content-Encoding: gzip')}
end
# proxied JSON
describe command('curl --compressed -sSvk "https://faalkaart.test/data/stats/NL/municipality/0"') do
  its(:stderr) {should contain('Content-Encoding: gzip')}
end
# proxied static files
describe command('curl --compressed -sSvk "https://faalkaart.test/static/images/internet_cleanup_foundation_logo.png"') do
  its(:stderr) {should contain('Content-Encoding: gzip')}
end

# HTTP2 request to frontend
describe command('sudo docker run --network=host getourneau/alpine-curl-http2 curl -sSvk https://faalkaart.test') do
  # should return successful
  its(:stderr) {should contain('HTTP/2 200')}
  # render complete page
  its(:stdout) {should contain('MSPAINT')}
  # HSTS security should be enabled
  its(:stderr) {should contain('strict-transport-security: max-age=31536000; includeSubdomains')}
end

describe command('curl -sSvk https://faalkaart.test/authentication/login/') do
  # should return successful
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
end

# multiple requests in quick succession to login
describe command('for i in 1..4; do curl -sSvk https://faalkaart.test/authentication/login/ &>/dev/null & done;curl -sSvk https://faalkaart.test/authentication/login/') do
  # should end up being rate limited
  its(:stderr) {should contain('HTTP/1.1 503 Service Temporarily Unavailable')}
end

# unauthenticated request to game
describe command('curl -sSvk https://faalkaart.test/game/') do
  # should be disallowed
  its(:stderr) {should contain('HTTP/1.1 404 Not Found')}
end

# authenticated request to game
describe command('curl -sSvk --cookie "sessionid=123" https://faalkaart.test/game/') do
  # should be allowed
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
end
