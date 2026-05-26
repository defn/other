package cli

import (
	"context"
	"sync"
)

// Latch is a one-shot typed value delivery mechanism.
// It coordinates between fx lifecycle (which starts before cobra parses flags)
// and cobra's RunE (which produces config after flag parsing).
type Latch[T any] struct {
	mu    sync.Mutex
	value T
	set   bool
	ch    chan struct{}
}

// NewLatch creates a new empty latch.
func NewLatch[T any]() *Latch[T] {
	return &Latch[T]{ch: make(chan struct{})}
}

// Set delivers the value, unblocking any waiters.
func (l *Latch[T]) Set(value T) {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.set {
		return
	}
	l.value = value
	l.set = true
	close(l.ch)
}

// Wait blocks until the value is set or the context is cancelled.
func (l *Latch[T]) Wait(ctx context.Context) (T, error) {
	select {
	case <-l.ch:
		l.mu.Lock()
		defer l.mu.Unlock()
		return l.value, nil
	case <-ctx.Done():
		var zero T
		return zero, ctx.Err()
	}
}

// TryGet returns the value if set, without blocking.
func (l *Latch[T]) TryGet() (T, bool) {
	l.mu.Lock()
	defer l.mu.Unlock()
	return l.value, l.set
}
