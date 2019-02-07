package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"regexp"
	"strings"
	"time"

	"github.com/chzyer/readline"

	"github.com/manifoldco/promptui"
)

const domainNameConfigFile = "/opt/failmap/server/configuration/settings.d/domainname.yaml"
const domainNameConfigTempl = `---
# configuration writting by 'failmap-server-tool'
apps::failmap::hostname: %s
letsencrypt::staging: false
letsencrypt::email: %s
`

type fact struct {
	collect func() (string, error)
	value   string
}

func (f *fact) Value() string {
	if f.value == "" {
		value, err := f.collect()
		if err != nil {
			fmt.Println(err)
			value = "-error-"
		}
		f.value = strings.TrimSpace(value)
	}
	return f.value
}

var facts = map[string]*fact{
	"Public IP Address": &fact{
		func() (string, error) { return cmdOutput("/opt/puppetlabs/bin/facter", "networking.ip") }, "",
	},
	"Server hostname": &fact{os.Hostname, ""},
	"Website domain name": &fact{
		func() (string, error) {
			return cmdOutput("/opt/puppetlabs/bin/puppet", "lookup",
				"--hiera_config=/opt/failmap/server/code/puppet/hiera.yaml",
				"--render-as=s", "apps::failmap::hostname", "--default=''")
		}, "",
	},
	"Administrative e-mail": &fact{
		func() (string, error) {
			return cmdOutput("/opt/puppetlabs/bin/puppet", "lookup",
				"--hiera_config=/opt/failmap/server/code/puppet/hiera.yaml",
				"--render-as=s", "letsencrypt::email", "--default=''")
		}, "",
	},
	"Server configuration version": &fact{
		func() (string, error) {
			return cmdOutput("git", "--git-dir=/opt/failmap/server/.git", "rev-list", "--all", "--count")
		}, "",
	},
	"Server configuration hash": &fact{
		func() (string, error) {
			return cmdOutput("git", "--git-dir=/opt/failmap/server/.git", "rev-parse", "--short", "HEAD")
		}, "",
	},
	"Application version": &fact{
		func() (string, error) {
			return cmdOutput("/usr/local/bin/failmap", "shell",
				"-c", "import failmap; print(failmap.__version__)")
		}, "",
	},
}

func cmdOutput(cmd string, args ...string) (string, error) {
	c := exec.Command(cmd, args...)
	out, err := c.Output()
	if err != nil {
		return "", fmt.Errorf("Failed to execute: '%s': %s, %s", cmd, err, c.Stderr)
	}
	return string(out), nil
}

func run(command string, args ...string) {
	cmd := exec.Command(command, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	c := make(chan os.Signal, 1)
	signal.Notify(c, os.Interrupt)
	go func() {
		for sig := range c {
			if sig == os.Interrupt {
				cmd.Process.Kill()
			}
		}
	}()
	err := cmd.Run()
	if err != nil {
		fmt.Printf("\n\033[2K%s\n\033[2K\n", err)
	}
}

type menuItem struct {
	Title  string
	action func()
}

func configureDomain() {
	fmt.Println("For proper security and HTTPS the domain name for the frontend needs to be explicitly configured.")
	prompt := promptui.Prompt{
		Label:     "What domain name should the frontend website be served under",
		Default:   facts["Website domain name"].Value(),
		AllowEdit: true,
		Validate: func(input string) error {
			if !regexp.MustCompile("^[a-z0-9\\._-]+\\.[a-z]+$").MatchString(input) {
				return errors.New("Not a valid domain name")
			}
			return nil
		},
	}
	domainName, err := prompt.Run()

	fmt.Printf("\nVerifying if domain name is usable...\n")
	var domainNameErrors []error
	_, err = net.LookupHost(domainName)
	if err != nil {
		domainNameErrors = append(domainNameErrors, fmt.Errorf("failed to resolve domain name: %s", err))
	}

	if len(domainNameErrors) != 0 {
		fmt.Println()
		for _, err := range domainNameErrors {
			fmt.Println(err)
		}
		fmt.Printf("\nWarning: the domain name %s does not resolve to an IP configured for this server.\n\n", domainName)
		fmt.Println("It is possible the domain name is configured properly but DNS has not propagated yet.\n")

		prompt := promptui.Prompt{
			Label:     "Do you want to continue configuration of this domain name",
			IsConfirm: true,
		}
		result, err := prompt.Run()
		if err != nil || strings.ToLower(result) != "y" {
			fmt.Println("Aborting")
			return
		}
	} else {
		fmt.Println("Domain name is valid.")
	}

	prompt = promptui.Prompt{
		Label:     "Please specify an email address that will be used for Letsencrypt (https)",
		Default:   facts["Administrative e-mail"].Value(),
		AllowEdit: true,
		Validate: func(input string) error {
			if !regexp.MustCompile("^.+@.+$").MatchString(input) {
				return errors.New("Not a valid e-mail address")
			}
			return nil
		},
	}
	emailAddress, err := prompt.Run()
	if err != nil {
		return
	}

	domainNameConfig := fmt.Sprintf(domainNameConfigTempl, domainName, emailAddress)
	fmt.Printf("The following configuration will been written to: %s\n", domainNameConfigFile)
	fmt.Println(domainNameConfig)
	fmt.Println("After this the new configuration will be applied.")
	prompt = promptui.Prompt{
		Label:     "Do you want to continue",
		IsConfirm: true,
	}
	result, err := prompt.Run()
	if err != nil || strings.ToLower(result) != "y" {
		fmt.Println("Aborting")
		return
	}

	err = ioutil.WriteFile(domainNameConfigFile,
		[]byte(domainNameConfig), 0644)
	if err != nil {
		fmt.Printf("\nFailed to write configuration to file!\n\n")
		return
	}
	run("/usr/local/bin/failmap-server-apply-configuration")
}

var menu = []menuItem{
	menuItem{"Show system information",
		func() {
			for k, v := range facts {
				fmt.Printf("%30s : %s\n", k, v.Value())
			}
		}},
	menuItem{"System statistics (cpu, memory, etc)", func() {
		fmt.Printf("\nPress [q] or [ctrl-c] to quit atop.\n")
		time.Sleep(1 * time.Second)
		run("atop")
	}},
	menuItem{"Live log tailing", func() {
		fmt.Printf("\nPress [ctrl-c] to quit journalctl.\n")
		time.Sleep(1 * time.Second)
		run("journalctl", "-f")
	}},
	menuItem{"Logging history", func() {
		fmt.Printf("\nPress [q] or [ctrl-c] to quit journalctl.\n")
		time.Sleep(1 * time.Second)
		run("journalctl")
	}},
	menuItem{"Configure domain name / Setup HTTPS", configureDomain},
	menuItem{"Update server configuration", func() { run("/usr/local/bin/failmap-server-update") }},
	menuItem{"Update Failmap application", func() { run("/usr/local/bin/failmap-deploy") }},
	menuItem{"Manage administrative users", func() { run("/usr/games/sl") }},
	// menuItem{"Enable/disable servertool at login", func() {
	// 	flagFile := os.Getenv("HOME") + "/.no_servertool"
	// 	if _, err := os.Stat(flagFile); os.IsNotExist(err) {
	// 		os.OpenFile(flagFile, os.O_RDONLY|os.O_CREATE, 0666)
	// 		fmt.Println("Disabling servertool at login")
	// 	} else {
	// 		os.Remove(flagFile)
	// 		fmt.Println("Enabling servertool at login")
	// 	}
	// }},
	menuItem{"Exit", func() { os.Exit(0) }},
}

func main() {
	if os.Geteuid() != 0 {
		fmt.Printf("Please run as root: sudo %s\n", os.Args[0])
		os.Exit(1)
	}

	templates := &promptui.SelectTemplates{
		Active:   fmt.Sprintf("%s {{ .Title | underline }}", promptui.IconSelect),
		Inactive: "  {{.Title }}",
		Selected: fmt.Sprintf(`{{ "%s" | green }} {{ .Title | faint }}`, promptui.IconGood),
	}

	prompt := promptui.Select{
		Label:     "Please make a choice",
		Size:      len(menu),
		Items:     menu,
		Templates: templates,
	}

	for {
		choice, _, err := prompt.Run()

		if err != nil {
			fmt.Printf("Aborted %v\n", err)
			break
		}

		menu[choice].action()
	}
}

// hack to disable terminal bell
// https://github.com/manifoldco/promptui/issues/49#issuecomment-428801411
type stderr struct{}

func (s *stderr) Write(b []byte) (int, error) {
	if len(b) == 1 && b[0] == 7 {
		return 0, nil
	}
	return os.Stderr.Write(b)
}

func (s *stderr) Close() error {
	return os.Stderr.Close()
}

func init() {
	readline.Stdout = &stderr{}

	// collect facts on the background at startup
	for _, v := range facts {
		go v.Value()
	}
}
