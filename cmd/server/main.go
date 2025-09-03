package main

import (
	"log"
	"url-shortener/internal/handlers"

	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()

	r.GET("/", func(c *gin.Context) {
		c.String(200, "URL-shortener API is running")
	})

	r.POST("/", handlers.CreateShortURL)

	r.GET("/:key", handlers.RedirectToURL)

	log.Println("Server is starting 8080")
	r.Run(":8080")
}
