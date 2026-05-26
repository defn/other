package tracetools

import (
	"context"

	"go.opentelemetry.io/otel"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/codes"
	"go.opentelemetry.io/otel/trace"
)

const (
	BackendDatadog       = "datadog"
	BackendOpenTelemetry = "opentelemetry"
	BackendNone          = ""
)

var ValidTracingBackends = map[string]struct{}{
	BackendOpenTelemetry: {},
	BackendNone:          {},
}

// StartSpanFromContext starts an OpenTelemetry span or returns a no-op.
func StartSpanFromContext(ctx context.Context, operation, tracingBackend string) (Span, context.Context) {
	switch tracingBackend {
	case BackendOpenTelemetry:
		ctx, span := otel.Tracer("defn-build").Start(ctx, operation)
		return &OpenTelemetrySpan{Span: span}, ctx
	default:
		return &NoopSpan{}, ctx
	}
}

// Span is the tracing span interface.
type Span interface {
	AddAttributes(map[string]string)
	FinishWithError(error)
	RecordError(error)
}

// OpenTelemetrySpan wraps an OpenTelemetry span.
type OpenTelemetrySpan struct {
	Span trace.Span
}

func NewOpenTelemetrySpan(base trace.Span) *OpenTelemetrySpan {
	return &OpenTelemetrySpan{Span: base}
}

func (s *OpenTelemetrySpan) AddAttributes(attributes map[string]string) {
	for k, v := range attributes {
		s.Span.SetAttributes(attribute.String(k, v))
	}
}

func (s *OpenTelemetrySpan) FinishWithError(err error) {
	s.RecordError(err)
	s.Span.End()
}

func (s *OpenTelemetrySpan) RecordError(err error) {
	if err == nil {
		return
	}
	s.Span.RecordError(err)
	s.Span.SetStatus(codes.Error, "failed")
}

// NoopSpan does nothing for every method.
type NoopSpan struct{}

func (s *NoopSpan) AddAttributes(map[string]string) {}
func (s *NoopSpan) FinishWithError(error)           {}
func (s *NoopSpan) RecordError(error)               {}
