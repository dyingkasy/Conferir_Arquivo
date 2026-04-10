package config

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

const defaultEnvFile = "/etc/conferearquivo/api.env"

type Config struct {
	AppEnv      string
	Host        string
	Port        int
	DatabaseURL string
}

func Load() (Config, error) {
	envFile := os.Getenv("CONFERE_API_ENV_FILE")
	if envFile == "" {
		envFile = defaultEnvFile
	}

	if err := loadDotEnv(envFile); err != nil && !errors.Is(err, os.ErrNotExist) {
		return Config{}, err
	}

	cfg := Config{
		AppEnv:      envOrDefault("APP_ENV", "production"),
		Host:        envOrDefault("API_HOST", "127.0.0.1"),
		DatabaseURL: strings.TrimSpace(os.Getenv("DATABASE_URL")),
	}

	port, err := strconv.Atoi(envOrDefault("API_PORT", "9015"))
	if err != nil {
		return Config{}, fmt.Errorf("invalid API_PORT: %w", err)
	}
	cfg.Port = port

	if cfg.DatabaseURL == "" {
		return Config{}, errors.New("DATABASE_URL is required")
	}

	return cfg, nil
}

func (c Config) ListenAddress() string {
	return fmt.Sprintf("%s:%d", c.Host, c.Port)
}

func loadDotEnv(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		key, value, found := strings.Cut(line, "=")
		if !found {
			continue
		}

		key = strings.TrimSpace(key)
		value = strings.TrimSpace(value)
		value = strings.Trim(value, `"'`)
		if key == "" {
			continue
		}
		if _, exists := os.LookupEnv(key); !exists {
			_ = os.Setenv(key, value)
		}
	}

	return scanner.Err()
}

func envOrDefault(key, fallback string) string {
	value := strings.TrimSpace(os.Getenv(key))
	if value == "" {
		return fallback
	}
	return value
}
