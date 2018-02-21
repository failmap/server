# test failmap frontend application
describe docker_container('failmap-frontend') do
  it { should exist }
end

# HTTP request to frontend
describe command('curl -sSvk https://faalkaart.nl') do
  # should return successful
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
  # render complete page
  its(:stdout) {should contain('MSPAINT')}
  # HSTS security should be enabled
  its(:stderr) {should contain('Strict-Transport-Security: max-age=31536000; includeSubdomains')}
end

# same for IPv6
describe command('curl -6 -sSvk https://faalkaart.nl') do
  # should return successful
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
  # render complete page
  its(:stdout) {should contain('MSPAINT')}
  # HSTS security should be enabled
  its(:stderr) {should contain('Strict-Transport-Security: max-age=31536000; includeSubdomains')}
end

# test some API calls
describe command('curl --compressed -sSvk "https://faalkaart.nl/data/stats/0"') do
  its(:stderr) {should contain('HTTP/1.1 200 OK')}
end

describe command('curl -sSv http://faalkaart.nl') do
  # should redirect to https
  its(:stderr) {should contain('HTTP/1.1 301')}
  its(:stderr) {should contain('Location: https://faalkaart.nl')}
end

describe command('curl -sSvk https://www.faalkaart.nl') do
  # should redirect www to no-www
  its(:stderr) {should contain('HTTP/1.1 301')}
  its(:stderr) {should contain('Location: https://faalkaart.nl')}
end

# stats have explicit cache which is different from the webserver 10 minute default
# implicitly tests database migrations as it will return 500 if they are not applied
describe command('curl -sSvk "https://faalkaart.nl/data/terrible_urls/0"') do
  # should redirect www to no-www
  its(:stderr) {should contain('Cache-Control: max-age=86400')}
end

# all responses should be compressed
# proxied html
describe command('curl --compressed -sSvk "https://faalkaart.nl/"') do
  its(:stderr) {should contain('Content-Encoding: gzip')}
end
# proxied JSON
describe command('curl --compressed -sSvk "https://faalkaart.nl/data/stats/0"') do
  its(:stderr) {should contain('Content-Encoding: gzip')}
end
# proxied static files
describe command('curl --compressed -sSvk "https://faalkaart.nl/static/images/internet_cleanup_foundation_logo.png"') do
  its(:stderr) {should contain('Content-Encoding: gzip')}
end

# HTTP2 request to frontend
describe command('sudo docker run getourneau/alpine-curl-http2 curl -sSvk https://faalkaart.nl') do
  # should return successful
  its(:stderr) {should contain('HTTP/2 200')}
  # render complete page
  its(:stdout) {should contain('MSPAINT')}
  # HSTS security should be enabled
  its(:stderr) {should contain('strict-transport-security: max-age=31536000; includeSubdomains')}
end
