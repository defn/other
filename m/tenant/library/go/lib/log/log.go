package log

import (
	"sync"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var (
	logger *zap.Logger
	once   sync.Once
	level  zap.AtomicLevel
)

// Init initializes the global logger at the given level.
func Init(l zapcore.Level) {
	once.Do(func() {
		level = zap.NewAtomicLevelAt(l)
		cfg := zap.NewProductionConfig()
		cfg.Level = level
		cfg.EncoderConfig.TimeKey = "ts"
		cfg.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
		var err error
		logger, err = cfg.Build()
		if err != nil {
			panic(err)
		}
	})
}

// Logger returns the global logger, initializing at info level if needed.
func Logger() *zap.Logger {
	if logger == nil {
		Init(zapcore.InfoLevel)
	}
	return logger
}

// SetLevel changes the log level dynamically.
func SetLevel(l zapcore.Level) {
	level.SetLevel(l)
}
