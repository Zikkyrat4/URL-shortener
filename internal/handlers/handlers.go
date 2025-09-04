package handlers

import (
	"math/rand"
	"net/url"
	"time"
	"url-shortener/internal/models"
	"url-shortener/internal/storage"

	"github.com/gin-gonic/gin"
)

func CreateShortURL(c *gin.Context, storage *storage.PostgresStorage) {
	var req models.CreateRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": "Invalid request"})
		return
	}

	if !isValidURL(req.URL) {
		c.JSON(400, gin.H{"error": "Invalid URL"})
		return
	}

	existingURL, err := storage.FindByOriginal(req.URL)
	if err == nil {
		c.JSON(200, models.CreateResponse{
			Key:      existingURL.Key,
			ShortURL: "http://localhost:8080/" + existingURL.Key,
		})
		return
	}

	key := generateUniqueKey(6, storage)

	newURL := &models.URL{
		Key:      key,
		Original: req.URL,
	}

	if err := storage.Save(newURL); err != nil {
		c.JSON(500, gin.H{"error": "Failed to save URL"})
		return
	}

	c.JSON(200, models.CreateResponse{
		Key:      key,
		ShortURL: "http://localhost:8080/" + key,
	})
}

func RedirectToURL(c *gin.Context, storage *storage.PostgresStorage) {
	key := c.Param("key")

	url, err := storage.FindByKey(key)
	if err != nil {
		c.JSON(404, gin.H{"error": "URL not found"})
		return
	}

	c.Redirect(302, url.Original)
}

func generateUniqueKey(length int, storage *storage.PostgresStorage) string {
	const charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	rand.New(rand.NewSource(time.Now().UnixNano()))

	for {
		b := make([]byte, length)
		for i := range b {
			b[i] = charset[rand.Intn(len(charset))]
		}
		key := string(b)

		_, err := storage.FindByKey(key)
		if err != nil {
			return key
		}
	}
}

func isValidURL(urlString string) bool {
	u, err := url.Parse(urlString)
	return err == nil && u.Scheme != "" && u.Host != ""
}
