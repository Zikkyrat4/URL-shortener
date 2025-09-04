package main

import (
	"log"
	"os"
	"url-shortener/internal/app"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "host=localhost user=postgres password=postgres dbname=urlshortener port=5432 sslmode=disable"
	}

	app, err := app.NewApp(dsn)
	if err != nil {
		log.Fatal("Failed to create app:", err)
	}

	log.Println("Server starting on :8080...")
	app.Router.Run(":8080")
}
