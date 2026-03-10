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
	password := os.Getenv("DB_PASSWORD")
	fmt.Println(password)
	if password == "" {
		return nil, fmt.Errorf("password is required")
	}
	serverPort := os.Getenv("SERVER_PORT")
	if serverPort == "" {
		serverPort = "8080"
	}
	return &Config{
		Host:        os.Getenv("DB_HOST"),
		Password:    password,
		ServerPort:  serverPort,
		DBName:      os.Getenv("DB_NAME"),
		Username:    os.Getenv("DB_USERNAME"),
		SSLMode:     os.Getenv("DB_SSLMODE"),
		Port:        os.Getenv("DB_PORT"),
		MaxOpenConn: 8,
		MaxIdleConn: 5,
	}, nil
}

func (s *Config) BuildDSN(config *Config) (string, error) {
	dsn := fmt.Sprintf("host=%s user=%s password=%s port=%s sslmode=%s", config.Host, config.Username, config.Password, config.Port, config.SSLMode)
	return dsn, nil
}
