package main

import (
	"fmt"
	"log"

	"github.com/imbivek08/school-crm/internal/config"
	"github.com/imbivek08/school-crm/internal/database"
	"github.com/imbivek08/school-crm/internal/server"
	"github.com/joho/godotenv"
)

func main() {
	fmt.Println("connecting to the database")
	godotenv.Load()
	cfg := &config.Config{}
	config, err := cfg.LoadEnv()
	if err != nil {
		log.Fatalf("failed to load configuration: %v", err)
	}
	db, err := database.New(config)
	if err != nil {
		log.Fatalf("failed to connect to the database:%v", err)
	}
	defer db.Close()
	log.Print("database connected successfully")
	srv := server.NewServer(config, db)
	if err := srv.Start(); err != nil {
		log.Fatalf("Failed to start the server:%v", err)
	}
}
