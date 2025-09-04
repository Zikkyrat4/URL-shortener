package app

import (
	"url-shortener/internal/cache"
	"url-shortener/internal/handlers"
	"url-shortener/internal/storage"

	"github.com/gin-gonic/gin"
)

type App struct {
	Router  *gin.Engine
	Storage *storage.PostgresStorage
	Cache   *cache.RedisCache
}

func NewApp(dsn string, redisAddr string) (*App, error) {
	storage, err := storage.NewPostgresStorage(dsn)
	if err != nil {
		return nil, err
	}

	redisCache, err := cache.NewRedisCache(redisAddr)
	if err != nil {
		return nil, err
	}

	app := &App{
		Router:  gin.Default(),
		Storage: storage,
		Cache:   redisCache,
	}

	app.setupRoutes()
	return app, nil
}

func (a *App) setupRoutes() {
	a.Router.GET("/", func(c *gin.Context) {
		c.String(200, "URL Shortener API with PostgreSQL and Redis!")
	})

	a.Router.POST("/", a.createShortURL)
	a.Router.GET("/:key", a.redirectToURL)
}

func (a *App) createShortURL(c *gin.Context) {
	handlers.CreateShortURL(c, a.Storage, a.Cache)
}

func (a *App) redirectToURL(c *gin.Context) {
	handlers.RedirectToURL(c, a.Storage, a.Cache)
}

func (a *App) Close() {
	if a.Cache != nil {
		a.Cache.Close()
	}
}
