package ratelimit

import (
	"testing"
	"time"
)

func TestLimiterBurstAndRefill(t *testing.T) {
	now := time.Date(2026, 11, 25, 12, 0, 0, 0, time.UTC)
	l := New(60, 2) // 1 req/sec, burst 2
	l.now = func() time.Time { return now }

	if !l.Allow("client-a") || !l.Allow("client-a") {
		t.Fatal("expected initial burst of 2 to succeed")
	}
	if l.Allow("client-a") {
		t.Fatal("expected 3rd immediate request to be rate-limited")
	}

	now = now.Add(1100 * time.Millisecond)
	if !l.Allow("client-a") {
		t.Fatal("expected request to succeed after token refill")
	}
}
