# admin login with remote_user should work
describe command('curl --http1.1 -sSvk --user wsm-user:wsm-user https://faalkaart.test/admin/') do
    # should be allowed
    its(:stderr) {should contain('HTTP/1.1 200 OK')}
    its(:stdout) {should contain('Web Security Map Admin')}
end
