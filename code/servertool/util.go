package main

import (
	"fmt"
	"os"
	"os/exec"
	"os/signal"
)

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
