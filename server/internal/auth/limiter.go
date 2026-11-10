package auth

import (
	"sync"
	"time"
)

// Limiter allows at most Max attempts per key within Window (e.g. 10
// login attempts per email per 15 minutes), in memory.
type Limiter struct {
	Max    int
	Window time.Duration

	mu   sync.Mutex
	hits map[string][]time.Time
	now  func() time.Time
}

func NewLimiter(max int, window time.Duration) *Limiter {
	return &Limiter{Max: max, Window: window, hits: map[string][]time.Time{}, now: time.Now}
}

// Allow records an attempt for key and reports whether it is allowed.
func (l *Limiter) Allow(key string) bool {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.now()
	cutoff := now.Add(-l.Window)
	recent := l.hits[key][:0]
	for _, t := range l.hits[key] {
		if t.After(cutoff) {
			recent = append(recent, t)
		}
	}
	if len(recent) >= l.Max {
		l.hits[key] = recent
		return false
	}
	l.hits[key] = append(recent, now)
	// Keep memory bounded: forget idle keys now and then.
	if len(l.hits) > 10_000 {
		for k, ts := range l.hits {
			if len(ts) == 0 || !ts[len(ts)-1].After(cutoff) {
				delete(l.hits, k)
			}
		}
	}
	return true
}

// Reset forgets a key (e.g. after a successful login).
func (l *Limiter) Reset(key string) {
	l.mu.Lock()
	defer l.mu.Unlock()
	delete(l.hits, key)
}
