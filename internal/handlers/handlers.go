package handlers

import (
	"math/rand"
	"time"
	"url-shortener/internal/models"

	"github.com/gin-gonic/gin"
)

var urlStore = make(map[string]string)

func CreateShortURL(c *gin.Context) {
	var req models.CreateRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": "Invalid request"})
		return
	}

	key := generateRandomKey(6)

	urlStore[key] = req.URL

	c.JSON(200, models.CreateResponse{
		Key:      key,
		ShortURL: "http://localhost:8080/" + key,
	})
}

func RedirectToURL(c *gin.Context) {
	key := c.Param("key")

	if originalURL, exists := urlStore[key]; exists {
		c.Redirect(302, originalURL)
	} else {
		c.JSON(404, gin.H{"error": "URL not found"})
	}
}

func generateRandomKey(length int) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	rand.Seed(time.Now().UnixNano())

	b := make([]byte, length)

	for i := range b {
		b[i] = charset[rand.Intn(len(charset))]
	}
	return string(b)
}
