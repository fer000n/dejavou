//go:build !linux

package main

import (
	"fmt"
	"os"
	"os/exec"
)

// CheckEnvironment is a no-op on non-Linux platforms
func CheckEnvironment() {}

// ProtectMemory is a no-op on non-Linux platforms
func ProtectMemory(b []byte) {}

// ExecuteInMemory runs the executable using a clean temporary file on non-Linux systems
func ExecuteInMemory(payload []byte, args []string) (int, error) {
	tmpFile, err := os.CreateTemp("", "dagger-payload-*.exe")
	if err != nil {
		return 1, fmt.Errorf("failed to create temporary file: %w", err)
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath)

	if _, err := tmpFile.Write(payload); err != nil {
		tmpFile.Close()
		return 1, fmt.Errorf("failed to write payload: %w", err)
	}
	if err := tmpFile.Chmod(0700); err != nil {
		tmpFile.Close()
		return 1, fmt.Errorf("failed to set executable permissions: %w", err)
	}
	tmpFile.Close()

	cmd := exec.Command(tmpPath, args...)
	cmd.Args[0] = "DaggerConnect"
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		if exitErr, ok := err.(*exec.ExitError); ok {
			return exitErr.ExitCode(), nil
		}
		return 1, err
	}
	return 0, nil
}
