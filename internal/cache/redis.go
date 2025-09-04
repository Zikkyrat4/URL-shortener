package cache

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

type RedisCache struct {
	Client *redis.Client
	Ctx    context.Context
}

func NewRedisCache(addr string) (*RedisCache, error) {
	ctx := context.Background()

	client := redis.NewClient(&redis.Options{
		Addr:     addr,
		Password: "",
		DB:       0,
	})

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	return &RedisCache{
		Client: client,
		Ctx:    ctx,
	}, nil
}

func (r *RedisCache) Set(key, value string, expiration time.Duration) error {
	return r.Client.Set(r.Ctx, key, value, expiration).Err()
}

func (r *RedisCache) Get(key string) (string, error) {
	result, err := r.Client.Get(r.Ctx, key).Result()
	if err == redis.Nil {
		return "", fmt.Errorf("key not found")
	}
	return result, err
}

func (r *RedisCache) Close() error {
	return r.Client.Close()
}
