package process

import (
	"os/exec"
	"strings"

	"github.com/defn/other/m/v/buildkite--agent/logger"
)

func Run(l logger.Logger, command string, arg ...string) (string, error) {
	output, err := exec.Command(command, arg...).Output()
	if err != nil {
		l.Debug("Could not run: %s %s (returned %s) (%T: %v)", command, arg, output, err, err)
		return "", err
	}

	return strings.Trim(string(output), "\n"), nil
}
