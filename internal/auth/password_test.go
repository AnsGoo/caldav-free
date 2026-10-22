package auth

import (
	"strings"
	"testing"
)

func TestHashAndVerify(t *testing.T) {
	hash, err := HashPassword("correct horse battery staple")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.HasPrefix(hash, "$pbkdf2-sha256$") {
		t.Fatalf("unexpected hash format: %s", hash)
	}
	if !VerifyPassword("correct horse battery staple", hash) {
		t.Fatal("valid password rejected")
	}
	if VerifyPassword("wrong password", hash) {
		t.Fatal("invalid password accepted")
	}
	if hash == mustHash(t, "correct horse battery staple") {
		t.Fatal("hashes should use a random salt")
	}
}

func TestVerifyRejectsMalformedHashes(t *testing.T) {
	cases := []string{
		"",
		"plaintext",
		"$pbkdf2-sha256$abc$c2FsdA$aGFzaA",
		"$pbkdf2-sha256$210000$c2FsdA$",
		"$pbkdf2-sha256$210000$c2FsdA$YQ",
		"$bcrypt$10$c2FsdA$aGFzaA",
	}
	for _, c := range cases {
		if VerifyPassword("anything", c) {
			t.Fatalf("malformed hash accepted: %q", c)
		}
	}
}

func TestRandomTokens(t *testing.T) {
	a := RandomToken(16)
	b := RandomToken(16)
	if len(a) < 20 || a == b {
		t.Fatalf("bad tokens: %q %q", a, b)
	}
	pw := RandomPassword()
	if len(pw) != 16 {
		t.Fatalf("password length = %d", len(pw))
	}
}

func mustHash(t *testing.T, password string) string {
	t.Helper()
	h, err := HashPassword(password)
	if err != nil {
		t.Fatal(err)
	}
	return h
}
