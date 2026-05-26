@experiment(aliasv2,explicitopen,shortcircuit,try)

package deps

deps: [
	"@io_opentelemetry_go_otel//:otel",
	"@io_opentelemetry_go_otel//attribute",
	"@io_opentelemetry_go_otel//codes",
	"@io_opentelemetry_go_otel_trace//:trace",
]
