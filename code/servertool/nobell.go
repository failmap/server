package main

import (
	"os"

	"github.com/chzyer/readline"
)

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
}
