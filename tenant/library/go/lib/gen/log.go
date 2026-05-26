package gen

import (
	"fmt"
	"os"
)

// LogOK prints a success message to stdout.
func (c *Context) LogOK(msg string) {
	if !c.Quiet {
		fmt.Fprintf(os.Stdout, "\u2713 %s\n", msg)
	}
}

// LogErr prints an error message to stderr.
func (c *Context) LogErr(msg string) {
	fmt.Fprintf(os.Stderr, "\u2717 %s\n", msg)
}
