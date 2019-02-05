package main

import (
	"fmt"
	"html/template"
	"os"
	"os/exec"
	"os/signal"

	"github.com/chzyer/readline"

	"github.com/manifoldco/promptui"
)

var infoTemplate = `Public IP: {{ .PublicIP }}
Server hostname: {{ .Hostname }}
Website domain name: {{ .Domainname }}
Administrative e-mail: {{ .AdminEmail }}

Server configuration version: {{ .ServerVersion }} ({{ .ServerCommit }})
Failmap application version: {{ .AppVersion }}
`

type facts struct {
	PublicIP      string
	Hostname      string
	Domainname    string
	AdminEmail    string
	ServerVersion string
	ServerCommit  string
	AppVersion    string
	gathered      bool
}

func (f *facts) gather() {
	if f.gathered == true {
		return
	}
}

type menuItem struct {
	id     string
	Title  string
	action func()
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

var menu = []menuItem{
	menuItem{"info", "Show system information", func() {
		f := facts{}
		f.gather()
		template.Must(template.New("name").Parse(infoTemplate)).Execute(os.Stdout, f)
	}},
	menuItem{"stats", "System statistics (cpu, memory, etc)", func() { run("atop") }},
	menuItem{"logs", "Live log tailing", func() { run("journalctl", "-f") }},
	menuItem{"loghistory", "Logging history", func() { run("journalctl") }},
	menuItem{"domainname", "Configure domain name / Setup HTTPS", func() {}},
	menuItem{"update_server", "Update server configuration", func() { run("/usr/local/bin/failmap-server-update") }},
	menuItem{"update_app", "Update Failmap application", func() { run("/usr/local/bin/failmap-deploy") }},
	menuItem{"manage_user", "Manage administrative users", func() { run("/usr/games/sl") }},

	menuItem{"exit", "Exit", func() { os.Exit(0) }},
}

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
}

func main() {
	for {
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

		choice, _, err := prompt.Run()

		if err != nil {
			fmt.Printf("Aborted %v\n", err)
			break
		}

		menu[choice].action()

	}
}
