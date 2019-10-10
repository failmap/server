package main

import (
	"fmt"
	"os"
	"strings"

	"encoding/json"
)

type fact struct {
	collect    func() (string, error)
	value      string
	collecting chan int
}

func (f *fact) Value() string {
	if f.collecting != nil {
		fmt.Println("Waiting for facts to be collected...")
		<-f.collecting
	}
	if f.value == "" {
		f.collecting = make(chan int)
		value, err := f.collect()
		close(f.collecting)
		f.collecting = nil
		if err != nil {
			fmt.Println(err)
			return "-error retrieving value-"
		}
		f.value = strings.TrimSpace(value)
	}
	return f.value
}

var facts = map[string]*fact{
	"Public IP Address": &fact{
		func() (string, error) { return cmdOutput("/opt/puppetlabs/bin/facter", "networking.ip") }, "", nil,
	},
	"Server hostname": &fact{os.Hostname, "", nil},
	"Website domain name": &fact{
		func() (string, error) {
			return cmdOutput("/opt/puppetlabs/bin/puppet", "lookup",
				"--hiera_config=/opt/websecmap/server/code/puppet/hiera.yaml",
				"--render-as=s", "apps::websecmap::hostname", "--default=''")
		}, "", nil,
	},
	"Administrative e-mail": &fact{
		func() (string, error) {
			return cmdOutput("/opt/puppetlabs/bin/puppet", "lookup",
				"--hiera_config=/opt/websecmap/server/code/puppet/hiera.yaml",
				"--render-as=s", "letsencrypt::email", "--default=''")
		}, "", nil,
	},
	"Server configuration version": &fact{
		func() (string, error) {
			return cmdOutput("git", "--git-dir=/opt/websecmap/server/.git", "rev-list", "--all", "--count")
		}, "", nil,
	},
	"Server configuration hash": &fact{
		func() (string, error) {
			return cmdOutput("git", "--git-dir=/opt/websecmap/server/.git", "rev-parse", "--short", "HEAD")
		}, "", nil,
	},
	"Configuration release channel": &fact{
		func() (string, error) {
			branch, err := cmdOutput("git", "--git-dir=/opt/websecmap/server/.git", "rev-parse", "--abbrev-ref", "HEAD")
			if err != nil {
				return "", err
			}
			if branch == "master" {
				return "default", nil
			}
			return branch, nil
		}, "", nil,
	},
	"Application version": &fact{
		func() (string, error) {
			return cmdOutput("/usr/local/bin/websecmap-no-tty", "shell",
				"-c", "import websecmap; print(websecmap.__version__)")
		}, "", nil,
	},
	"Administrative users": &fact{
		func() (string, error) {
			accountData, err := cmdOutput("/opt/puppetlabs/bin/puppet", "lookup",
				"--hiera_config=/opt/websecmap/server/code/puppet/hiera.yaml",
				"--render-as=json", "--merge=deep", "accounts::users", "--default=")
			if err != nil {
				return "", err
			}
			// puppet lookup returns two doublequotes instead of nothing if default is empty
			if strings.TrimSpace(accountData) == "\"\"" {
				accountData = "{}"
			}
			type Account struct {
				Ensure string
				Sudo   bool
			}
			var accounts map[string]Account
			err = json.Unmarshal([]byte(accountData), &accounts)
			if err != nil {
				return "", err
			}
			var adminUsers []string
			for username, account := range accounts {
				if account.Sudo {
					adminUsers = append(adminUsers, username)
				}
			}

			return strings.Join(adminUsers, ","), nil
		}, "", nil,
	},
}

func init() {
	// collect facts on the background at startup
	for k := range facts {
		go facts[k].Value()
	}
}
