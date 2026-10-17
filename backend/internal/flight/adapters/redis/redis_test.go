package redis_test

import (
	"context"
	"io"
	"log/slog"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	goredis "github.com/redis/go-redis/v9"

	flightredis "wanderplan/backend/internal/flight/adapters/redis"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

func TestCacheAndLock(t *testing.T) {
	mr := miniredis.RunT(t)
	rdb := goredis.NewClient(&goredis.Options{Addr: mr.Addr()})
	ctx := context.Background()
	cache := flightredis.NewCache(rdb, slog.New(slog.NewTextHandler(io.Discard, nil)))
	key := "flight:v1:3U1234:2026-12-05"
	if _, ok := cache.Get(ctx, key); ok {
		t.Fatal("empty cache")
	}
	f := domain.Flight{Code: "3U1234", Date: kernel.NewDate(2026, 12, 5), Status: &domain.Status{Phase: domain.PhaseScheduled}}
	cache.Set(ctx, key, f, 24*time.Hour)
	got, ok := cache.Get(ctx, key)
	if !ok || got.Code != "3U1234" || got.Status.Phase != domain.PhaseScheduled {
		t.Fatalf("%+v", got)
	}
	mr.FastForward(25 * time.Hour)
	if _, ok := cache.Get(ctx, key); ok {
		t.Fatal("entries expire after their TTL")
	}

	locks := flightredis.NewLocker(rdb)
	release, ok, err := locks.TryLock(ctx, "lock:"+key, 30*time.Second)
	if err != nil || !ok {
		t.Fatal(ok, err)
	}
	if _, ok, _ := locks.TryLock(ctx, "lock:"+key, 30*time.Second); ok {
		t.Fatal("a second instance must not get the lock")
	}
	release()
	if _, ok, _ := locks.TryLock(ctx, "lock:"+key, 30*time.Second); !ok {
		t.Fatal("released locks can be taken again")
	}
	// An expired lock taken over by someone else is not released by the old owner.
	mr2 := miniredis.RunT(t)
	r2 := goredis.NewClient(&goredis.Options{Addr: mr2.Addr()})
	l2 := flightredis.NewLocker(r2)
	oldRelease, _, _ := l2.TryLock(ctx, "k", time.Second)
	mr2.FastForward(2 * time.Second)
	_, ok, _ = l2.TryLock(ctx, "k", time.Minute)
	oldRelease()
	if !mr2.Exists("k") || !ok {
		t.Fatal("the new owner's lock must survive the old owner's release")
	}
}
