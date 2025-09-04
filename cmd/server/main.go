package main

import (
	"log"
	"os"
	"url-shortener/internal/app"
)

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "host=localhost user=postgres password=postgres dbname=urlshortener port=5433 sslmode=disable"
	}

	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}

	log.Printf("Connecting to database: %s", dsn)
	log.Printf("Connecting to Redis: %s", redisAddr)

	app, err := app.NewApp(dsn, redisAddr)
	if err != nil {
		log.Fatal("Failed to create app:", err)
	}
	defer app.Close()

	log.Println("Server starting on :8080...")
	app.Router.Run(":8080")
}
