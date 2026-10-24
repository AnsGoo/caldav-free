package web

import (
	"testing"
	"time"
)

func TestPublicRateLimiter(t *testing.T) {
	limiter := newPublicRateLimiter(2, 100*time.Millisecond)
	if ok, _ := limiter.allow("127.0.0.1"); !ok {
		t.Fatal("first request rejected")
	}
	if ok, _ := limiter.allow("127.0.0.1"); !ok {
		t.Fatal("second request rejected")
	}
	ok, retry := limiter.allow("127.0.0.1")
	if ok || retry <= 0 {
		t.Fatalf("third request = %v, retry %v; want limited", ok, retry)
	}
	if ok, _ := limiter.allow("10.0.0.2"); !ok {
		t.Fatal("independent IP rejected")
	}
	time.Sleep(120 * time.Millisecond)
	if ok, _ := limiter.allow("127.0.0.1"); !ok {
		t.Fatal("request after window rejected")
	}
}
