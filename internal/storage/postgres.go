package storage

import (
	"fmt"
	"time"
	"url-shortener/internal/models"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

type PostgresStorage struct {
	DB *gorm.DB
}

func NewPostgresStorage(dsn string) (*PostgresStorage, error) {
	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %w", err)
	}

	err = db.AutoMigrate(&models.URL{})
	if err != nil {
		return nil, fmt.Errorf("failed to migrate database: %w", err)
	}

	return &PostgresStorage{DB: db}, nil
}

func (s *PostgresStorage) Save(url *models.URL) error {
	url.CreatedAt = time.Now()
	result := s.DB.Create(url)
	return result.Error
}

func (s *PostgresStorage) FindByKey(key string) (*models.URL, error) {
	var url models.URL
	result := s.DB.Where("key = ?", key).First(&url)
	if result.Error != nil {
		return nil, result.Error
	}
	return &url, nil
}

func (s *PostgresStorage) FindByOriginal(original string) (*models.URL, error) {
	var url models.URL
	result := s.DB.Where("original = ?", original).First(&url)
	if result.Error != nil {
		return nil, result.Error
	}
	return &url, nil
}
