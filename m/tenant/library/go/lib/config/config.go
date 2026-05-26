package config

import (
	"github.com/spf13/viper"
)

// Init sets up viper with default configuration sources.
// Priority: env (DEFN_ prefix) > ./defn.yaml > ~/.defn.yaml
func Init() {
	viper.SetEnvPrefix("DEFN")
	viper.AutomaticEnv()

	viper.SetConfigName("defn")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("$HOME")

	// Ignore missing config file -- env and flags still work.
	_ = viper.ReadInConfig()
}
