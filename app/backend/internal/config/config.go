package config

import (
	"fmt"
	"os"
)

type Config struct {
	Host        string
	Username    string
	Password    string
	Port        string
	DBName      string
	SSLMode     string
	MaxOpenConn int8
	MaxIdleConn int8

	ServerPort string
}

func (s *Config) LoadEnv() (*Config, error) {
	password := os.Getenv("PASSWORD")
	if password == "" {
		return nil, fmt.Errorf("password is required")
	}
	serverPort := os.Getenv("SERVER_")
	if serverPort == "" {
		serverPort = "8080"
	}
	return &Config{
		Host:        os.Getenv("HOST"),
		Password:    password,
		ServerPort:  serverPort,
		DBName:      os.Getenv("DB_NAME"),
		Username:    os.Getenv("USERNAME"),
		SSLMode:     os.Getenv("SSL_MODE"),
		MaxOpenConn: 8,
		MaxIdleConn: 5,
	}, nil
}

func (s *Config) BuildDSN(config *Config) (string, error) {
	dsn := fmt.Sprintf("host=%s user=%s password=%s port=%s sslmode=%s", config.Host, config.Username, config.Password, config.Port, config.SSLMode)
	return dsn, nil
}
