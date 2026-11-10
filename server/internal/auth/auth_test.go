package auth

import (
	"testing"
	"time"
)

func TestPasswordHashing(t *testing.T) {
	h, err := HashPassword("correct horse")
	if err != nil {
		t.Fatal(err)
	}
	if !VerifyPassword("correct horse", h) {
		t.Fatal("right password rejected")
	}
	if VerifyPassword("wrong horse", h) {
		t.Fatal("wrong password accepted")
	}
	h2, _ := HashPassword("correct horse")
	if h == h2 {
		t.Fatal("same hash twice: salt missing")
	}
	if VerifyPassword("x", "garbage") || VerifyPassword("x", "pbkdf2-sha256$0$a$b") {
		t.Fatal("malformed hash accepted")
	}
}

func TestPasswordPolicy(t *testing.T) {
	if CheckPasswordPolicy("short") == nil {
		t.Fatal("short password accepted")
	}
	if CheckPasswordPolicy("رمز‌عبور۱۲۳") != nil {
		t.Fatal("8+ Persian characters rejected")
	}
}

func TestTokens(t *testing.T) {
	a, ha, _ := NewToken()
	b, _, _ := NewToken()
	if a == b || len(a) < 40 {
		t.Fatalf("weak tokens %q %q", a, b)
	}
	if string(HashToken(a)) != string(ha) {
		t.Fatal("hash mismatch")
	}
}

func TestLimiter(t *testing.T) {
	now := time.Unix(0, 0)
	l := NewLimiter(3, time.Minute)
	l.now = func() time.Time { return now }
	for i := 0; i < 3; i++ {
		if !l.Allow("k") {
			t.Fatalf("attempt %d blocked", i+1)
		}
	}
	if l.Allow("k") {
		t.Fatal("4th attempt allowed")
	}
	if !l.Allow("other") {
		t.Fatal("other key blocked")
	}
	now = now.Add(61 * time.Second)
	if !l.Allow("k") {
		t.Fatal("not allowed after the window")
	}
	l.Reset("k")
	for i := 0; i < 3; i++ {
		if !l.Allow("k") {
			t.Fatal("reset didn't clear")
		}
	}
}
