package models

import "time"

type URL struct {
	ID        uint      `json:"id"`
	Key       string    `gorm:"uniqueIndex;not null" json:"key"`
	Original  string    `gorm:"not null" json:"original_url"`
	CreatedAt time.Time `json:"created_at"`
}

type CreateRequest struct {
	URL string `json:"url" binding:"required"`
}

type CreateResponse struct {
	Key      string `json:"key"`
	ShortURL string `json:"short_url"`
}
