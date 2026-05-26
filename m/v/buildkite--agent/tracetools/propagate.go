package tracetools

import (
	"encoding/gob"
	"encoding/json"
	"fmt"
	"io"
)

// EnvVarTraceContextKey is the env var key for encoded trace context.
const EnvVarTraceContextKey = "BUILDKITE_TRACE_CONTEXT"

// Encoder impls can encode values. Decoder impls can decode values.
type (
	Encoder interface{ Encode(v any) error }
	Decoder interface{ Decode(v any) error }
)

// Codec implementations produce encoders/decoders.
type Codec interface {
	NewEncoder(io.Writer) Encoder
	NewDecoder(io.Reader) Decoder
	String() string
}

// CodecGob marshals and unmarshals with encoding/gob.
type CodecGob struct{}

func (CodecGob) NewEncoder(w io.Writer) Encoder { return gob.NewEncoder(w) }
func (CodecGob) NewDecoder(r io.Reader) Decoder { return gob.NewDecoder(r) }
func (CodecGob) String() string                 { return "gob" }

// CodecJSON marshals and unmarshals with encoding/json.
type CodecJSON struct{}

func (CodecJSON) NewEncoder(w io.Writer) Encoder { return json.NewEncoder(w) }
func (CodecJSON) NewDecoder(r io.Reader) Decoder { return json.NewDecoder(r) }
func (CodecJSON) String() string                 { return "json" }

// ParseEncoding converts an encoding to the associated codec.
func ParseEncoding(encoding string) (Codec, error) {
	switch encoding {
	case "", "gob":
		return CodecGob{}, nil
	case "json":
		return CodecJSON{}, nil
	default:
		return nil, fmt.Errorf("invalid encoding %q", encoding)
	}
}
