# test base features like a secure firewall, users, motd, etc.

describe iptables do
  it { should have_rule('-P INPUT ACCEPT') }
end
