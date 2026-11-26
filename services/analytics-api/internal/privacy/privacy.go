package privacy

import (
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/hex"
	"net"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// SaltRotator generates a daily ephemeral random salt kept strictly in memory.
// Raw client IP addresses are never persisted, logged, or published.
type SaltRotator struct {
	mu   sync.Mutex
	day  string
	salt []byte
	now  func() time.Time
}

// NewSaltRotator creates a SaltRotator backed by UTC calendar days.
func NewSaltRotator() *SaltRotator {
	return &SaltRotator{now: func() time.Time { return time.Now().UTC() }}
}

// SessionID derives a 16-hex-char ephemeral pseudonymous identifier for the current UTC day.
func (s *SaltRotator) SessionID(clientIP, userAgent string) string {
	today := s.now().Format("2006-01-02")

	s.mu.Lock()
	if s.day != today || len(s.salt) == 0 {
		buf := make([]byte, 32)
		_, _ = rand.Read(buf)
		s.salt = buf
		s.day = today
	}
	salt := s.salt
	s.mu.Unlock()

	mac := hmac.New(sha256.New, salt)
	mac.Write([]byte(clientIP))
	mac.Write([]byte("|"))
	mac.Write([]byte(userAgent))
	sum := mac.Sum(nil)
	return hex.EncodeToString(sum[:8])
}

// ClientIP extracts the leftmost forwarded IP (set by Google Cloud Load Balancer) or RemoteAddr.
func ClientIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		if ip := strings.TrimSpace(parts[0]); ip != "" {
			return ip
		}
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

// ReferrerDomain extracts only the lowercase hostname from a referrer URL to prevent leaking tokens/paths.
func ReferrerDomain(raw string) string {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "direct"
	}
	u, err := url.Parse(raw)
	if err != nil || u.Hostname() == "" {
		return "unknown"
	}
	return strings.ToLower(u.Hostname())
}

// ClassifyDevice maps a User-Agent string to desktop, mobile, tablet, or bot.
func ClassifyDevice(ua string) string {
	lower := strings.ToLower(ua)
	if IsBot(ua) {
		return "bot"
	}
	switch {
	case strings.Contains(lower, "ipad"), strings.Contains(lower, "tablet"):
		return "tablet"
	case strings.Contains(lower, "mobile"), strings.Contains(lower, "android"), strings.Contains(lower, "iphone"):
		return "mobile"
	default:
		return "desktop"
	}
}

var botSubstrings = []string{
	"bot", "crawler", "spider", "slurp", "mediapartners",
	"googlehc", "uptime", "kube-probe", "curl/", "wget/",
	"python-requests", "go-http-client", "headlesschrome", "lighthouse",
}

// IsBot returns true for automated health checks, crawlers, and synthetic monitors.
func IsBot(ua string) bool {
	lower := strings.ToLower(strings.TrimSpace(ua))
	if lower == "" {
		return true
	}
	for _, token := range botSubstrings {
		if strings.Contains(lower, token) {
			return true
		}
	}
	return false
}
