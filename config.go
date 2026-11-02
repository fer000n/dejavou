package main

import (
	"encoding/json"
	"fmt"
	"net"
	"os"
)

// PathConfig specifies client path endpoints
type PathConfig struct {
	Addr string `json:"addr"`
}

// ListenerConfig specifies server listener endpoints
type ListenerConfig struct {
	Addr string `json:"addr"`
}

// Config represents the DaggerLauncher JSON configuration schema
type Config struct {
	Mode      string           `json:"mode"`
	PSK       string           `json:"psk"`
	Paths     []PathConfig     `json:"paths,omitempty"`
	Listeners []ListenerConfig `json:"listeners,omitempty"`
}

// LoadConfig reads, unmarshals, and validates the configuration file
func LoadConfig(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file %q: %w", path, err)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config JSON: %w", err)
	}

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("invalid config: %w", err)
	}

	return &cfg, nil
}

// Validate verifies configuration consistency based on mode and carriers
func (c *Config) Validate() error {
	switch c.Mode {
	case "client", "server":
	default:
		return fmt.Errorf("unknown mode %q (must be 'client' or 'server')", c.Mode)
	}

	hasCarrier := false
	if len(c.Paths) > 0 {
		hasCarrier = true
		for i, p := range c.Paths {
			if _, _, err := net.SplitHostPort(p.Addr); err != nil {
				return fmt.Errorf("invalid path[%d] addr %q: %w", i, p.Addr, err)
			}
		}
	}

	if len(c.Listeners) > 0 {
		hasCarrier = true
		for i, l := range c.Listeners {
			if _, _, err := net.SplitHostPort(l.Addr); err != nil {
				return fmt.Errorf("invalid listener[%d] addr %q: %w", i, l.Addr, err)
			}
		}
	}

	if !hasCarrier {
		return fmt.Errorf("config requires at least one carrier: a path to dial or a listener to bind")
	}

	return nil
}

