package main

import (
	"errors"
	"fmt"
	"io/ioutil"
	"net"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/manifoldco/promptui"
	"github.com/sethvargo/go-password/password"
	"gopkg.in/yaml.v2"
)

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

	const domainNameConfigFile = "/opt/failmap/server/configuration/settings.d/domainname.yaml"

	domainNameConfig, _ := yaml.Marshal(struct {
		Hostname string `yaml:"apps::failmap::hostname"`
		Email    string `yaml:"letsencrypt::email"`
		Staging  bool   `yaml:"letsencrypt::staging"`
	}{
		domainName,
		emailAddress,
		false,
	})

	fmt.Printf("The following configuration will been written to: %s\n", domainNameConfigFile)
	fmt.Println(string(domainNameConfig))
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

	facts["Website domain name"].value = domainName
	facts["Administrative e-mail"].value = emailAddress
}

func configureUsers() {
	var err error
	defer func() {
		if err != nil {
			fmt.Printf("Error: %s", err)
		}
	}()
	accounts := strings.Split(facts["Administrative users"].Value(), ",")

	prompt := promptui.Select{
		Label: "Modify/delete existing administrative user, or add new one",
		Size:  len(accounts) + 1,
		Items: append(accounts, "Add new administrative user"),
	}
	_, choice, err := prompt.Run()
	if err != nil {
		return
	}

	type Account struct {
		Ensure      string
		Sudo        bool
		WebPassword string
		SSHPubKey   string
	}
	var username string
	account := Account{
		"present",
		true,
		"",
		"",
	}
	var generatePassword bool
	var setSSHPubKey bool

	if choice == "Add new administrative user" {
		prompt := promptui.Prompt{
			Label: "Please specify the desired username",
			Validate: func(input string) error {
				if !regexp.MustCompile("^[a-zA-Z0-9_]+$").MatchString(input) {
					return errors.New("Not a valid username")
				}
				return nil
			},
		}
		username, err = prompt.Run()
		if err != nil {
			return
		}
		generatePassword = true

		prompt = promptui.Prompt{
			Label:     fmt.Sprintf("Do you want to add a public key for SSH login"),
			IsConfirm: true,
		}

		if result, _ := prompt.Run(); strings.ToLower(result) == "y" {
			setSSHPubKey = true
		}
	} else {
		username = choice

		prompt := promptui.Select{
			Label: fmt.Sprintf("What action do you want to perform on user '%s'", username),
			Size:  3,
			Items: []string{"Generate new password", "Set SSH public key", "Delete user"},
		}
		_, choice, err := prompt.Run()
		if err != nil {
			return
		}

		switch choice {
		case "Generate new password":
			generatePassword = true
		case "Set SSH public key":
			setSSHPubKey = true
		case "Delete user":
			prompt := promptui.Prompt{
				Label:     fmt.Sprintf("Are you sure you want to delete user '%s'", username),
				IsConfirm: true,
			}
			result, err := prompt.Run()
			if err != nil || strings.ToLower(result) != "y" {
				return
			}
			account.Ensure = "absent"
			account.Sudo = false
		}
	}

	if generatePassword {
		account.WebPassword, err = password.Generate(64, 10, 10, false, false)
		if err != nil {
			return
		}

		fmt.Println("The following password was generated for this user:")
		fmt.Println()
		fmt.Println(account.WebPassword)
		fmt.Println()
		fmt.Println("It can only be used to log into the web interface.")
		fmt.Println("The password cannot be changed, but you can regenerate a ")
		fmt.Println("new and secure password using this tool at any time.")
		fmt.Println()
		fmt.Println("Please note this password cannot be used to login using SSH.")
		fmt.Println("For SSH login set a public key for the user.")
		fmt.Println()
	}
	if setSSHPubKey {
		fmt.Println("SSH public/private key pair is used to allow the user to login via SSH.")
		fmt.Println("For more information refer to: https://help.ubuntu.com/community/SSH/OpenSSH/Keys")
		fmt.Println("")
		fmt.Println("For security reasons we disallow password based SSH login.")
		prompt := promptui.Prompt{
			Label: "Please provide the SSH public key",
			Validate: func(input string) error {
				if !regexp.MustCompile("^AAAA[0-9A-Za-z+/]+[=]{0,3}$").MatchString(input) {
					return errors.New("Invalid SSH public key, only the 'key' part should be provided. Omit the 'ssh-rsa' prefix and 'name' at the end")
				}
				return nil
			},
		}
		account.SSHPubKey, err = prompt.Run()
		if err != nil {
			return
		}
	}

	// write the user account settings into Hiera and apply configuration
	data, err := yaml.Marshal(struct {
		Accounts map[string]Account `yaml:"accounts::users"`
	}{Accounts: map[string]Account{username: account}})
	var filename = fmt.Sprintf("/opt/failmap/server/configuration/settings.d/%s.yaml", username)
	err = ioutil.WriteFile(filename, []byte(data), 0644)
	if err != nil {
		fmt.Printf("\nFailed to write configuration to file!\n\n")
		return
	}
	run("/usr/local/bin/failmap-server-apply-configuration")

	facts["Administrative users"].value = ""
	go facts["Administrative users"].Value()
}

func updateServerConfig() {
	// TODO: move to update.sh??
	branch := facts["Configuration release channel"].Value()
	if branch != "master" {
		fmt.Printf("You are currently on the '%s' release channel.\n", branch)
		fmt.Println("This is not the main release channel!")
		time.Sleep(1 * time.Second)
	}

	run("/usr/local/bin/failmap-server-update")

	// TODO: relaunch servertool if binary was updated?
}

var menu = []menuItem{
	menuItem{"Show system information",
		func() {
			for k, v := range facts {
				fmt.Printf("%30s : %s\n", k, v.Value())
			}
		}},
	menuItem{"", func() {}},
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
	menuItem{"", func() {}},
	menuItem{"Configure domain name / Setup HTTPS", configureDomain},
	menuItem{"Manage administrative users / SSH access", configureUsers},
	menuItem{"", func() {}},
	menuItem{"Update server configuration", updateServerConfig},
	menuItem{"Update Failmap application", func() { run("/usr/local/bin/failmap-deploy") }},
	menuItem{"", func() {}},
	menuItem{"Upgrade to Failmap PRO", func() { run("/usr/games/sl") }},
	menuItem{"", func() {}},
	menuItem{"Enable/disable servertool at login", func() {
		flagFile := "/home/" + os.Getenv("SUDO_USER") + "/.no_servertool"
		if _, err := os.Stat(flagFile); os.IsNotExist(err) {
			os.OpenFile(flagFile, os.O_RDONLY|os.O_CREATE, 0666)
			fmt.Println("Disabling servertool at login")
		} else {
			os.Remove(flagFile)
			fmt.Println("Enabling servertool at login")
		}
	}},
	menuItem{"Escape to shell", func() { run(os.Getenv("SHELL")) }},
	menuItem{"Exit/Logout", func() { os.Exit(0) }},
}

func main() {
	if os.Geteuid() != 0 {
		fmt.Printf("Please run as root: sudo %s\n", os.Args[0])
		// os.Exit(1)
	}

	fmt.Println()
	fmt.Println("Welcome to the Failmap server administration tool.")
	fmt.Println()
	fmt.Println("This tool will help with basic configuration tasks and")
	fmt.Println("incidental maintenance/monitoring.")
	fmt.Println()
	fmt.Println("At any time use [ctrl]+[c] to abort/exit.")
	fmt.Println()

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
		fmt.Println()
		choice, _, err := prompt.Run()

		if err != nil {
			fmt.Printf("Aborted %v\n", err)
			break
		}

		menu[choice].action()
	}
}
