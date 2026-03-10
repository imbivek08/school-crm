package main

import (
	"log"

	"github.com/imbivek08/school-crm/internal/config"
	"github.com/imbivek08/school-crm/internal/database"
)

func main() {
	cfg := &config.Config{}
	config, err := cfg.LoadEnv()
	if err != nil {
		log.Fatalf("failed to load configuration: %w", err)
	}
	db, err := database.New(config)
	if err != nil {
		log.Fatalf("failed to connect to the database:%w", err)
	}
	defer db.Close()
	log.Print("database connected successfully")
}
