package ratelimit

import (
	"sync"
	"time"
)

type bucket struct {
	tokens   float64
	lastSeen time.Time
}

// Limiter implements a bounded, in-memory per-key token bucket rate limiter.
type Limiter struct {
	mu           sync.Mutex
	buckets      map[string]*bucket
	ratePerSec   float64
	burst        float64
	maxEntries   int
	ttl          time.Duration
	now          func() time.Time
}

// New creates a Limiter allowing perMinute requests/min with the given burst size.
func New(perMinute, burst int) *Limiter {
	return &Limiter{
		buckets:    make(map[string]*bucket),
		ratePerSec: float64(perMinute) / 60.0,
		burst:      float64(burst),
		maxEntries: 10000,
		ttl:        15 * time.Minute,
		now:        time.Now,
	}
}

// Allow reports whether a request from key is permitted right now.
func (l *Limiter) Allow(key string) bool {
	now := l.now()

	l.mu.Lock()
	defer l.mu.Unlock()

	if len(l.buckets) >= l.maxEntries {
		l.evictStaleLocked(now)
	}

	b, ok := l.buckets[key]
	if !ok {
		b = &bucket{tokens: l.burst, lastSeen: now}
		l.buckets[key] = b
	}

	elapsed := now.Sub(b.lastSeen).Seconds()
	b.tokens += elapsed * l.ratePerSec
	if b.tokens > l.burst {
		b.tokens = l.burst
	}
	b.lastSeen = now

	if b.tokens < 1.0 {
		return false
	}
	b.tokens -= 1.0
	return true
}

func (l *Limiter) evictStaleLocked(now time.Time) {
	for k, b := range l.buckets {
		if now.Sub(b.lastSeen) > l.ttl {
			delete(l.buckets, k)
		}
	}
}
