package main

import (
	"os"
	"regexp"
)

// EnvConfig contains configuration parameters loaded from environment variables
type EnvConfig struct {
	Channel   string
	Version   string
	ServerURL string
	ClientURL string
}

var semverPattern = regexp.MustCompile(`^[vV]?[0-9]+(\.[0-9]+)*(-[a-zA-Z0-9._-]+)?$`)

// LoadEnv reads and validates DC_* environment variables
func LoadEnv() *EnvConfig {
	channel := os.Getenv("DC_CHANNEL")
	if channel != "beta" {
		channel = "release"
	}

	version := os.Getenv("DC_VERSION")
	if version == "" || (!semverPattern.MatchString(version) && version != "latest") {
		version = "latest"
	}

	return &EnvConfig{
		Channel:   channel,
		Version:   version,
		ServerURL: os.Getenv("DC_SERVER_URL"),
		ClientURL: os.Getenv("DC_CLIENT_URL"),
	}
}

