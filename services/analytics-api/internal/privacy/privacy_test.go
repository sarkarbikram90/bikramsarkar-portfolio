package privacy

import (
	"testing"
	"time"
)

func TestSaltRotatorSessionIDRotatesDaily(t *testing.T) {
	now := time.Date(2026, 11, 25, 12, 0, 0, 0, time.UTC)
	rotator := &SaltRotator{now: func() time.Time { return now }}

	id1 := rotator.SessionID("203.0.113.10", "Mozilla/5.0")
	id2 := rotator.SessionID("203.0.113.10", "Mozilla/5.0")
	if id1 != id2 {
		t.Fatalf("expected deterministic session ID within same day, got %s vs %s", id1, id2)
	}
	if len(id1) != 16 {
		t.Fatalf("expected 16-char hex session ID, got %d (%s)", len(id1), id1)
	}

	now = now.Add(24 * time.Hour)
	idNextDay := rotator.SessionID("203.0.113.10", "Mozilla/5.0")
	if idNextDay == id1 {
		t.Fatalf("expected session ID to rotate on next UTC day")
	}
}

func TestReferrerDomainStripsPathAndQuery(t *testing.T) {
	cases := map[string]string{
		"":                                            "direct",
		"https://www.LinkedIn.com/in/bikram?token=1":  "www.linkedin.com",
		"https://github.com/sarkarbikram90/portfolio": "github.com",
		"not a url :::":                               "unknown",
	}
	for input, want := range cases {
		if got := ReferrerDomain(input); got != want {
			t.Errorf("ReferrerDomain(%q) = %q, want %q", input, got, want)
		}
	}
}

func TestBotAndDeviceClassification(t *testing.T) {
	if !IsBot("GoogleHC/1.0") {
		t.Error("expected GoogleHC to be classified as bot")
	}
	if !IsBot("kube-probe/1.34") {
		t.Error("expected kube-probe to be classified as bot")
	}
	if !IsBot("") {
		t.Error("expected empty UA to be classified as bot")
	}
	if got := ClassifyDevice("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Mobile"); got != "mobile" {
		t.Errorf("expected mobile, got %s", got)
	}
	if got := ClassifyDevice("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"); got != "desktop" {
		t.Errorf("expected desktop, got %s", got)
	}
}
