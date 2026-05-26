// Package version provides agent version strings.
package version

import (
	"fmt"
	"runtime"
)

const baseVersion = "0.0.1"

func Version() string { return baseVersion }

func BuildNumber() string { return "0" }

func FullVersion() string {
	return fmt.Sprintf("%s+%s", Version(), BuildNumber())
}

func UserAgent() string {
	return fmt.Sprintf("defn-build/%s (%s; %s)", Version(), runtime.GOOS, runtime.GOARCH)
}
