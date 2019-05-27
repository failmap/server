describe command('curl --http1.1 -sSv http://faalkaart.test') do
    # should redirect to https
    its(:stderr) {should contain('HTTP/1.1 301')}
    its(:stderr) {should contain('Location: https://faalkaart.test')}
  end

describe command('curl --http1.1 -sSvk https://www.faalkaart.test') do
    # should redirect www to no-www
    its(:stderr) {should contain('HTTP/1.1 301')}
    its(:stderr) {should contain('Location: https://faalkaart.test')}
  end
