package richtext

import (
	"strings"
	"testing"
)

func TestSanitizeAllowlist(t *testing.T) {
	input := `<p onclick="alert(1)">Hello <strong>world</strong><script>alert(1)</script>` +
		`<img src=x onerror="alert(1)"><a href="javascript:alert(1)">bad</a>` +
		`<a href="https://example.com" target="_blank">safe</a></p>` +
		`<span style="color: #ff0000; background-image: url(x)">red</span>`
	out := Sanitize(input)
	if strings.Contains(out, "script") || strings.Contains(out, "onclick") || strings.Contains(out, "onerror") || strings.Contains(out, "javascript:") {
		t.Fatalf("unsafe markup survived: %s", out)
	}
	if strings.Contains(out, "background-image") || strings.Contains(out, "url(") {
		t.Fatalf("unsafe style survived: %s", out)
	}
	if !strings.Contains(out, "<strong>world</strong>") {
		t.Fatalf("formatting lost: %s", out)
	}
	if !strings.Contains(out, `href="https://example.com"`) || !strings.Contains(out, "noopener noreferrer") {
		t.Fatalf("safe link lost: %s", out)
	}
	if !strings.Contains(out, "color: #ff0000") {
		t.Fatalf("safe style lost: %s", out)
	}
}

func TestPlainAndFromPlain(t *testing.T) {
	plain := Plain(`<p>第一段 <strong>加粗</strong></p><ul><li>条目一</li><li>条目二</li></ul>`)
	if !strings.Contains(plain, "第一段 加粗") || !strings.Contains(plain, "条目一") {
		t.Fatalf("plain text = %q", plain)
	}
	if strings.Contains(plain, "<") {
		t.Fatalf("plain text contains tags: %q", plain)
	}
	html := FromPlain("第一行\n第二行 <script>")
	if !strings.Contains(html, "<p>第一行</p>") || strings.Contains(html, "<script>") || !strings.Contains(html, "&lt;script&gt;") {
		t.Fatalf("from plain = %q", html)
	}
}
