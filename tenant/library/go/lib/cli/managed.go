package cli

import (
	"context"
	"sync"

	"go.uber.org/fx"
	"go.uber.org/zap"
)

// ServiceRunner defines how a command's service runs.
type ServiceRunner[C any] interface {
	Run(ctx context.Context, cfg C, onReady func(error)) error
	Stop(ctx context.Context) error
}

// Managed wraps a ServiceRunner with fx lifecycle integration.
// It bridges the gap between fx's startup (before cobra parses flags)
// and the actual service execution (after flags are parsed).
type Managed[C any] struct {
	latch  *Latch[C]
	runner ServiceRunner[C]
	logger *zap.Logger

	ready chan error
	done  chan struct{}
	err   error
	mu    sync.Mutex
}

// NewManaged creates a new Managed service wrapper.
func NewManaged[C any](latch *Latch[C], runner ServiceRunner[C], logger *zap.Logger) *Managed[C] {
	return &Managed[C]{
		latch:  latch,
		runner: runner,
		logger: logger,
		ready:  make(chan error, 1),
		done:   make(chan struct{}),
	}
}

// RegisterLifecycle hooks into the fx lifecycle.
func (m *Managed[C]) RegisterLifecycle(lc fx.Lifecycle) {
	lc.Append(fx.Hook{
		OnStart: func(ctx context.Context) error {
			go m.run(ctx)
			return nil
		},
		OnStop: func(ctx context.Context) error {
			return m.runner.Stop(ctx)
		},
	})
}

func (m *Managed[C]) run(ctx context.Context) {
	defer close(m.done)

	cfg, err := m.latch.Wait(ctx)
	if err != nil {
		// Context cancellation is expected for non-invoked commands --
		// all modules start, but only the invoked command sets its latch.
		if ctx.Err() != nil {
			m.logger.Debug("latch wait canceled (command not invoked)", zap.Error(err))
		} else {
			m.logger.Error("latch wait failed", zap.Error(err))
		}
		m.ready <- err
		return
	}

	onReady := func(err error) {
		m.ready <- err
	}

	if err := m.runner.Run(ctx, cfg, onReady); err != nil {
		m.mu.Lock()
		m.err = err
		m.mu.Unlock()
		m.logger.Error("service exited with error", zap.Error(err))
	}
}

// WaitForReady blocks until the service signals readiness.
func (m *Managed[C]) WaitForReady(ctx context.Context) error {
	select {
	case err := <-m.ready:
		return err
	case <-ctx.Done():
		return ctx.Err()
	}
}

// WaitForDone blocks until the service exits.
func (m *Managed[C]) WaitForDone(ctx context.Context) error {
	select {
	case <-m.done:
		m.mu.Lock()
		defer m.mu.Unlock()
		return m.err
	case <-ctx.Done():
		return ctx.Err()
	}
}
