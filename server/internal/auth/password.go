package auth

import (
	"crypto/pbkdf2"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"strconv"
	"strings"
	"unicode/utf8"
)

// PBKDF2-SHA256 with OWASP's recommended iteration count (2023+).
const (
	iterations = 600_000
	saltLen    = 16
	keyLen     = 32
)

// MinPasswordLength for new passwords.
const MinPasswordLength = 8

var ErrWeakPassword = fmt.Errorf("password must be at least %d characters", MinPasswordLength)

// CheckPasswordPolicy validates a new password.
func CheckPasswordPolicy(password string) error {
	if utf8.RuneCountInString(password) < MinPasswordLength {
		return ErrWeakPassword
	}
	if len(password) > 256 {
		return errors.New("password is too long")
	}
	return nil
}

// HashPassword returns "pbkdf2-sha256$<iter>$<salt>$<hash>".
func HashPassword(password string) (string, error) {
	salt := make([]byte, saltLen)
	if _, err := rand.Read(salt); err != nil {
		return "", err
	}
	key, err := pbkdf2.Key(sha256.New, password, salt, iterations, keyLen)
	if err != nil {
		return "", err
	}
	enc := base64.RawStdEncoding
	return fmt.Sprintf("pbkdf2-sha256$%d$%s$%s", iterations, enc.EncodeToString(salt), enc.EncodeToString(key)), nil
}

// VerifyPassword checks a password against a stored hash in constant time.
func VerifyPassword(password, stored string) bool {
	parts := strings.Split(stored, "$")
	if len(parts) != 4 || parts[0] != "pbkdf2-sha256" {
		return false
	}
	iter, err := strconv.Atoi(parts[1])
	if err != nil || iter < 1 {
		return false
	}
	enc := base64.RawStdEncoding
	salt, err1 := enc.DecodeString(parts[2])
	want, err2 := enc.DecodeString(parts[3])
	if err1 != nil || err2 != nil {
		return false
	}
	got, err := pbkdf2.Key(sha256.New, password, salt, iter, len(want))
	if err != nil {
		return false
	}
	return subtle.ConstantTimeCompare(got, want) == 1
}

// dummyHash is verified against when the email doesn't exist, so a
// login takes the same time either way (no user enumeration by timing).
var dummyHash, _ = HashPassword("not-a-real-password")

// SpendTime does the work of one password check.
func SpendTime(password string) { VerifyPassword(password, dummyHash) }
