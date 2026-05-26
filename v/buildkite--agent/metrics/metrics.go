// Package metrics provides build agent metrics collection.
// Currently a no-op; will be wired to an OpenTelemetry metrics backend.
package metrics

import (
	"time"

	"github.com/defn/other/m/v/buildkite--agent/logger"
)

// Collector collects metrics. Currently a no-op.
type Collector struct {
	logger logger.Logger
}

// CollectorConfig configures the metrics collector.
type CollectorConfig struct{}

// NewCollector creates a new metrics collector.
func NewCollector(l logger.Logger, _ CollectorConfig) *Collector {
	return &Collector{logger: l}
}

// Start is a no-op.
func (c *Collector) Start() error { return nil }

// Stop is a no-op.
func (c *Collector) Stop() error { return nil }

// Scope returns a metrics scope with the given tags.
func (c *Collector) Scope(tags Tags) *Scope {
	return &Scope{Tags: tags, c: c}
}

// Scope is a tagged metrics scope.
type Scope struct {
	Tags Tags
	c    *Collector
}

// Timing records timing information. Currently a no-op.
func (s *Scope) Timing(_ string, _ time.Duration, _ ...Tags) {}

// Count tracks how many times something happened. Currently a no-op.
func (s *Scope) Count(_ string, _ int64, _ ...Tags) {}

// With returns a scope with additional tags.
func (s *Scope) With(tags Tags) *Scope {
	merged := Tags{}
	for k, v := range s.Tags {
		merged[k] = v
	}
	for k, v := range tags {
		merged[k] = v
	}
	return &Scope{Tags: merged, c: s.c}
}

// Tags is a map of metric tag key-value pairs.
type Tags map[string]string
