package richtext

import (
	"regexp"
	"strings"
	"unicode"

	"golang.org/x/net/html"
	"golang.org/x/net/html/atom"
)

// MaxNoteHTML bounds a single rich-text note before parsing.
const MaxNoteHTML = 300 * 1024

var (
	allowedTags = map[string]bool{
		"p": true, "br": true, "div": true, "span": true,
		"strong": true, "b": true, "em": true, "i": true, "u": true,
		"s": true, "strike": true, "del": true, "mark": true,
		"code": true, "pre": true, "blockquote": true,
		"h1": true, "h2": true, "h3": true, "h4": true,
		"ul": true, "ol": true, "li": true, "a": true, "hr": true,
		"sub": true, "sup": true, "font": true,
	}
	droppedTags = map[string]bool{
		"script": true, "style": true, "iframe": true, "object": true,
		"embed": true, "svg": true, "math": true, "template": true,
		"form": true, "input": true, "textarea": true, "select": true,
		"button": true, "video": true, "audio": true, "source": true,
		"link": true, "meta": true, "base": true,
	}
	blockTags = map[string]bool{
		"p": true, "div": true, "li": true, "h1": true, "h2": true,
		"h3": true, "h4": true, "blockquote": true, "pre": true,
		"ul": true, "ol": true, "table": true, "tr": true, "hr": true,
	}
	colorRE  = regexp.MustCompile(`^(#[0-9a-fA-F]{3,8}|rgba?\([0-9.,\s%]+\)|hsla?\([0-9.,\s%]+\)|[a-zA-Z]{3,24})$`)
	sizeRE   = regexp.MustCompile(`^[0-9]{1,3}(px|em|rem|%)$`)
	alignRE  = regexp.MustCompile(`^(left|right|center|justify)$`)
	weightRE = regexp.MustCompile(`^(normal|bold|bolder|lighter|[1-9]00)$`)
)

// Sanitize keeps only a small allowlist of formatting tags and attributes.
// Unknown formatting tags are unwrapped; active-content tags are dropped.
func Sanitize(input string) string {
	if strings.TrimSpace(input) == "" {
		return ""
	}
	if len(input) > MaxNoteHTML {
		input = input[:MaxNoteHTML]
	}
	doc, err := html.Parse(strings.NewReader(input))
	if err != nil {
		return ""
	}
	body := findElement(doc, "body")
	if body == nil {
		return ""
	}
	root := &html.Node{Type: html.ElementNode, Data: "div", DataAtom: atom.Div}
	for child := body.FirstChild; child != nil; child = child.NextSibling {
		sanitizeNode(child, root)
	}
	var out strings.Builder
	for child := root.FirstChild; child != nil; child = child.NextSibling {
		if err := html.Render(&out, child); err != nil {
			return ""
		}
	}
	return out.String()
}

func sanitizeNode(node *html.Node, parent *html.Node) {
	switch node.Type {
	case html.TextNode:
		parent.AppendChild(&html.Node{Type: html.TextNode, Data: node.Data})
		return
	case html.ElementNode:
	default:
		return
	}
	tag := strings.ToLower(node.Data)
	if droppedTags[tag] {
		return
	}
	if !allowedTags[tag] {
		for child := node.FirstChild; child != nil; child = child.NextSibling {
			sanitizeNode(child, parent)
		}
		return
	}
	if tag == "a" {
		href := attr(node, "href")
		if !safeURL(href) {
			for child := node.FirstChild; child != nil; child = child.NextSibling {
				sanitizeNode(child, parent)
			}
			return
		}
	}
	clean := &html.Node{Type: html.ElementNode, Data: tag, DataAtom: atom.Lookup([]byte(tag))}
	switch tag {
	case "a":
		clean.Attr = append(clean.Attr, html.Attribute{Key: "href", Val: attr(node, "href")})
		if title := attr(node, "title"); title != "" {
			clean.Attr = append(clean.Attr, html.Attribute{Key: "title", Val: title})
		}
		if attr(node, "target") == "_blank" {
			clean.Attr = append(clean.Attr, html.Attribute{Key: "target", Val: "_blank"})
		}
		clean.Attr = append(clean.Attr, html.Attribute{Key: "rel", Val: "noopener noreferrer"})
	case "font":
		if color := attr(node, "color"); color != "" && colorRE.MatchString(color) {
			clean.Attr = append(clean.Attr, html.Attribute{Key: "color", Val: color})
		}
	}
	if style := attr(node, "style"); style != "" {
		if safe := sanitizeStyle(style); safe != "" {
			clean.Attr = append(clean.Attr, html.Attribute{Key: "style", Val: safe})
		}
	}
	parent.AppendChild(clean)
	for child := node.FirstChild; child != nil; child = child.NextSibling {
		sanitizeNode(child, clean)
	}
}

// Plain extracts readable text for previews, search and the notes_text mirror.
func Plain(input string) string {
	if strings.TrimSpace(input) == "" {
		return ""
	}
	doc, err := html.Parse(strings.NewReader(input))
	if err != nil {
		return strings.TrimSpace(input)
	}
	body := findElement(doc, "body")
	if body == nil {
		return strings.TrimSpace(input)
	}
	var out strings.Builder
	writePlain(body, &out)
	text := out.String()
	text = strings.ReplaceAll(text, "\r\n", "\n")
	lines := strings.Split(text, "\n")
	for index, line := range lines {
		lines[index] = strings.Join(strings.Fields(line), " ")
	}
	text = strings.Join(lines, "\n")
	text = strings.TrimSpace(text)
	for strings.Contains(text, "\n\n\n") {
		text = strings.ReplaceAll(text, "\n\n\n", "\n\n")
	}
	return text
}

func writePlain(node *html.Node, out *strings.Builder) {
	if node.Type == html.TextNode {
		out.WriteString(node.Data)
		return
	}
	if node.Type != html.ElementNode {
		return
	}
	tag := strings.ToLower(node.Data)
	if droppedTags[tag] {
		return
	}
	if tag == "br" {
		out.WriteByte('\n')
		return
	}
	if blockTags[tag] {
		out.WriteByte('\n')
	}
	for child := node.FirstChild; child != nil; child = child.NextSibling {
		writePlain(child, out)
	}
	if blockTags[tag] {
		out.WriteByte('\n')
	}
}

// FromPlain converts legacy plain text into escaped HTML paragraphs.
func FromPlain(input string) string {
	text := strings.ReplaceAll(input, "\r\n", "\n")
	text = strings.TrimSpace(text)
	if text == "" {
		return ""
	}
	var out strings.Builder
	for _, line := range strings.Split(text, "\n") {
		if strings.TrimSpace(line) == "" {
			continue
		}
		out.WriteString("<p>")
		out.WriteString(html.EscapeString(line))
		out.WriteString("</p>")
	}
	return out.String()
}

func findElement(root *html.Node, tag string) *html.Node {
	for node := root.FirstChild; node != nil; node = node.NextSibling {
		if node.Type == html.ElementNode && strings.EqualFold(node.Data, tag) {
			return node
		}
		if found := findElement(node, tag); found != nil {
			return found
		}
	}
	return nil
}

func attr(node *html.Node, key string) string {
	for _, item := range node.Attr {
		if strings.EqualFold(item.Key, key) {
			return strings.TrimSpace(item.Val)
		}
	}
	return ""
}

func safeURL(raw string) bool {
	value := strings.TrimSpace(strings.ToLower(raw))
	if value == "" {
		return false
	}
	for _, ch := range value {
		if unicode.IsControl(ch) {
			return false
		}
	}
	if strings.HasPrefix(value, "javascript:") || strings.HasPrefix(value, "data:") || strings.HasPrefix(value, "vbscript:") {
		return false
	}
	if strings.HasPrefix(value, "#") || strings.HasPrefix(value, "/") || strings.HasPrefix(value, "./") || strings.HasPrefix(value, "../") {
		return true
	}
	return strings.HasPrefix(value, "http://") || strings.HasPrefix(value, "https://") || strings.HasPrefix(value, "mailto:") || strings.HasPrefix(value, "tel:")
}

func sanitizeStyle(raw string) string {
	parts := strings.Split(raw, ";")
	allowed := make([]string, 0, len(parts))
	for _, part := range parts {
		key, value, ok := strings.Cut(part, ":")
		if !ok {
			continue
		}
		key = strings.ToLower(strings.TrimSpace(key))
		value = strings.TrimSpace(value)
		valid := false
		switch key {
		case "color", "background-color":
			valid = colorRE.MatchString(value)
		case "font-size":
			valid = sizeRE.MatchString(value)
		case "text-align":
			valid = alignRE.MatchString(value)
		case "font-weight":
			valid = weightRE.MatchString(value)
		case "font-style":
			valid = value == "normal" || value == "italic" || value == "oblique"
		case "text-decoration":
			valid = value == "none" || value == "underline" || value == "line-through" || value == "underline line-through"
		}
		if valid {
			allowed = append(allowed, key+": "+value)
		}
	}
	return strings.Join(allowed, "; ")
}
