package handlers

import (
	"log"
	"net/url"
	"time"
	"url-shortener/internal/cache"
	"url-shortener/internal/models"
	"url-shortener/internal/storage"

	"github.com/gin-gonic/gin"

	"math/rand"
)

func CreateShortURL(c *gin.Context, storage *storage.PostgresStorage, cache *cache.RedisCache) {
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
		cache.Set(existingURL.Key, existingURL.Original, 24*time.Hour)

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

	cache.Set(key, req.URL, 24*time.Hour)

	c.JSON(200, models.CreateResponse{
		Key:      key,
		ShortURL: "http://localhost:8080/" + key,
	})
}

func RedirectToURL(c *gin.Context, storage *storage.PostgresStorage, cache *cache.RedisCache) {
	key := c.Param("key")

	if cachedURL, err := cache.Get(key); err == nil {
		log.Printf("Cache HIT for key: %s", key)
		c.Redirect(302, cachedURL)
		return
	}

	log.Printf("Cache MISS for key: %s", key)

	url, err := storage.FindByKey(key)
	if err != nil {
		c.JSON(404, gin.H{"error": "URL not found"})
		return
	}

	cache.Set(key, url.Original, 24*time.Hour)

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
