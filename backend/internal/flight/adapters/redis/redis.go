// Package redis is the shared cache and distributed lock for flight data:
// every API instance sees the same "flight:v1:{code}:{date}" entries, and a
// flight is refreshed by one instance at a time.
package redis

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"log/slog"
	"time"

	goredis "github.com/redis/go-redis/v9"

	"wanderplan/backend/internal/flight/domain"
)

type Cache struct {
	rdb *goredis.Client
	log *slog.Logger
}

func NewCache(rdb *goredis.Client, log *slog.Logger) *Cache { return &Cache{rdb: rdb, log: log} }

// Get returns the cached flight. Redis being down is not an error: the caller
// falls back to PostgreSQL.
func (c *Cache) Get(ctx context.Context, key string) (*domain.Flight, bool) {
	raw, err := c.rdb.Get(ctx, key).Bytes()
	if err != nil {
		if err != goredis.Nil {
			c.log.Warn("redis get failed", "error", err)
		}
		return nil, false
	}
	var f domain.Flight
	if err := json.Unmarshal(raw, &f); err != nil {
		return nil, false
	}
	return &f, true
}

func (c *Cache) Set(ctx context.Context, key string, f domain.Flight, ttl time.Duration) {
	raw, err := json.Marshal(f)
	if err == nil {
		err = c.rdb.Set(ctx, key, raw, ttl).Err()
	}
	if err != nil {
		c.log.Warn("redis set failed", "error", err)
	}
}

type Locker struct{ rdb *goredis.Client }

func NewLocker(rdb *goredis.Client) *Locker { return &Locker{rdb: rdb} }

// release deletes the lock only if we still own it (token check), so an
// expired lock taken over by another instance is never removed by us.
var release = goredis.NewScript(`if redis.call("get", KEYS[1]) == ARGV[1] then return redis.call("del", KEYS[1]) else return 0 end`)

func (l *Locker) TryLock(ctx context.Context, key string, ttl time.Duration) (func(), bool, error) {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	token := hex.EncodeToString(b)
	ok, err := l.rdb.SetNX(ctx, key, token, ttl).Result()
	if err != nil || !ok {
		return nil, false, err
	}
	return func() { _ = release.Run(context.WithoutCancel(ctx), l.rdb, []string{key}, token).Err() }, true, nil
}
