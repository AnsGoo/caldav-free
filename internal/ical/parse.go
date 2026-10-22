// Package ical implements the subset of iCalendar (RFC 5545) needed by a
// CalDAV server: parsing, serialization, timezone handling, recurrence
// expansion, time-range filtering and free/busy generation.
package ical

import (
	"errors"
	"fmt"
	"sort"
	"strings"
)

// Params holds property parameters. Values are stored unquoted and ^-unescaped.
type Params map[string][]string

// Get returns the first value for a parameter name (case-insensitive).
func (p Params) Get(name string) string {
	vs := p[strings.ToUpper(name)]
	if len(vs) == 0 {
		return ""
	}
	return vs[0]
}

// Values returns all values for a parameter.
func (p Params) Values(name string) []string {
	return p[strings.ToUpper(name)]
}

// Set replaces a parameter with a single value.
func (p Params) Set(name, value string) {
	p[strings.ToUpper(name)] = []string{value}
}

// Add appends a parameter value.
func (p Params) Add(name, value string) {
	name = strings.ToUpper(name)
	p[name] = append(p[name], value)
}

// Del removes a parameter.
func (p Params) Del(name string) { delete(p, strings.ToUpper(name)) }

// Clone returns a deep copy.
func (p Params) Clone() Params {
	out := make(Params, len(p))
	for k, vs := range p {
		out[k] = append([]string(nil), vs...)
	}
	return out
}

// Prop is one content line.
type Prop struct {
	Name   string
	Params Params
	Value  string
}

// Clone returns a deep copy of the property.
func (p Prop) Clone() Prop {
	return Prop{Name: p.Name, Params: p.Params.Clone(), Value: p.Value}
}

// Component is a VCALENDAR, VEVENT, VTODO, VJOURNAL, VTIMEZONE, ...
type Component struct {
	Name     string
	Props    []Prop
	Children []*Component
}

// NewComponent creates an empty component with the given name.
func NewComponent(name string) *Component {
	return &Component{Name: strings.ToUpper(name), Props: []Prop{}}
}

// AddProp appends a property.
func (c *Component) AddProp(name, value string, params Params) *Component {
	if params == nil {
		params = Params{}
	}
	c.Props = append(c.Props, Prop{Name: strings.ToUpper(name), Params: params, Value: value})
	return c
}

// SetProp replaces all properties with the name, preserving the first position.
func (c *Component) SetProp(name, value string, params Params) *Component {
	name = strings.ToUpper(name)
	if params == nil {
		params = Params{}
	}
	for i := range c.Props {
		if c.Props[i].Name == name {
			c.Props[i].Value = value
			c.Props[i].Params = params
			return c
		}
	}
	c.Props = append(c.Props, Prop{Name: name, Params: params, Value: value})
	return c
}

// RemoveProps removes every property with the given name.
func (c *Component) RemoveProps(name string) {
	name = strings.ToUpper(name)
	dst := c.Props[:0]
	for _, p := range c.Props {
		if p.Name != name {
			dst = append(dst, p)
		}
	}
	c.Props = dst
}

// AddChild appends a nested component.
func (c *Component) AddChild(child *Component) *Component {
	c.Children = append(c.Children, child)
	return c
}

// Get returns the first property with the given name.
func (c *Component) Get(name string) *Prop {
	name = strings.ToUpper(name)
	for i := range c.Props {
		if c.Props[i].Name == name {
			return &c.Props[i]
		}
	}
	return nil
}

// All returns every property with the given name.
func (c *Component) All(name string) []*Prop {
	name = strings.ToUpper(name)
	var out []*Prop
	for i := range c.Props {
		if c.Props[i].Name == name {
			out = append(out, &c.Props[i])
		}
	}
	return out
}

// Value returns the first property's value, or "".
func (c *Component) Value(name string) string {
	if p := c.Get(name); p != nil {
		return p.Value
	}
	return ""
}

// Child returns the first nested component with the given name.
func (c *Component) Child(name string) *Component {
	name = strings.ToUpper(name)
	for _, ch := range c.Children {
		if ch.Name == name {
			return ch
		}
	}
	return nil
}

// ChildrenNamed returns all nested components with the given name.
func (c *Component) ChildrenNamed(name string) []*Component {
	name = strings.ToUpper(name)
	var out []*Component
	for _, ch := range c.Children {
		if ch.Name == name {
			out = append(out, ch)
		}
	}
	return out
}

// Clone deep-copies a component tree.
func (c *Component) Clone() *Component {
	if c == nil {
		return nil
	}
	out := &Component{Name: c.Name, Props: make([]Prop, len(c.Props)), Children: make([]*Component, 0, len(c.Children))}
	for i, p := range c.Props {
		out.Props[i] = p.Clone()
	}
	for _, ch := range c.Children {
		out.Children = append(out.Children, ch.Clone())
	}
	return out
}

// Parse parses iCalendar data and returns the first VCALENDAR component.
func Parse(data []byte) (*Component, error) {
	root, err := ParseAll(data)
	if err != nil {
		return nil, err
	}
	return root, nil
}

// ParseAll parses iCalendar data and returns the outermost component
// (normally VCALENDAR).
func ParseAll(data []byte) (*Component, error) {
	text := string(data)
	text = strings.TrimPrefix(text, "\ufeff")
	text = strings.ReplaceAll(text, "\r\n", "\n")
	text = strings.ReplaceAll(text, "\r", "\n")

	rawLines := strings.Split(text, "\n")
	lines := make([]string, 0, len(rawLines))
	for _, line := range rawLines {
		if len(line) > 0 && (line[0] == ' ' || line[0] == '\t') {
			if len(lines) == 0 {
				return nil, errors.New("ical: folded line at start of input")
			}
			lines[len(lines)-1] += line[1:]
			continue
		}
		if strings.TrimSpace(line) == "" {
			continue
		}
		lines = append(lines, line)
	}
	if len(lines) == 0 {
		return nil, errors.New("ical: empty calendar data")
	}

	var root *Component
	var stack []*Component
	for i, line := range lines {
		name, value, params, err := parseContentLine(line)
		if err != nil {
			return nil, fmt.Errorf("ical: line %d: %w", i+1, err)
		}
		switch name {
		case "BEGIN":
			comp := NewComponent(value)
			if len(stack) > 0 {
				parent := stack[len(stack)-1]
				parent.Children = append(parent.Children, comp)
			} else if root == nil {
				root = comp
			} else {
				return nil, errors.New("ical: multiple top-level components")
			}
			stack = append(stack, comp)
		case "END":
			if len(stack) == 0 {
				return nil, fmt.Errorf("ical: unexpected END:%s", value)
			}
			top := stack[len(stack)-1]
			if top.Name != strings.ToUpper(value) {
				return nil, fmt.Errorf("ical: END:%s does not match BEGIN:%s", value, top.Name)
			}
			stack = stack[:len(stack)-1]
		default:
			if len(stack) == 0 {
				return nil, fmt.Errorf("ical: property %s outside of a component", name)
			}
			stack[len(stack)-1].Props = append(stack[len(stack)-1].Props, Prop{Name: name, Params: params, Value: value})
		}
	}
	if len(stack) != 0 {
		return nil, fmt.Errorf("ical: unterminated component %s", stack[len(stack)-1].Name)
	}
	if root == nil {
		return nil, errors.New("ical: no component found")
	}
	if root.Name != "VCALENDAR" {
		return nil, fmt.Errorf("ical: expected VCALENDAR, got %s", root.Name)
	}
	return root, nil
}

// parseContentLine splits "NAME;PARAM=VALUE:value" respecting quoted strings.
func parseContentLine(line string) (name, value string, params Params, err error) {
	colon := indexUnquoted(line, ':')
	if colon < 0 {
		return "", "", nil, errors.New("missing ':' separator")
	}
	left := line[:colon]
	value = line[colon+1:]

	parts := splitUnquoted(left, ';')
	if len(parts) == 0 || strings.TrimSpace(parts[0]) == "" {
		return "", "", nil, errors.New("missing property name")
	}
	name = strings.ToUpper(strings.TrimSpace(parts[0]))
	params = Params{}
	for _, part := range parts[1:] {
		eq := indexUnquoted(part, '=')
		if eq < 0 {
			return "", "", nil, fmt.Errorf("invalid parameter %q", part)
		}
		pname := strings.ToUpper(strings.TrimSpace(part[:eq]))
		pvalue := strings.TrimSpace(part[eq+1:])
		if pname == "" {
			return "", "", nil, errors.New("empty parameter name")
		}
		for _, v := range splitUnquoted(pvalue, ',') {
			params[pname] = append(params[pname], unquoteParam(strings.TrimSpace(v)))
		}
	}
	return name, value, params, nil
}

func indexUnquoted(s string, target byte) int {
	inQuotes := false
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '"':
			inQuotes = !inQuotes
		case '\\':
			if inQuotes {
				i++
			}
		default:
			if !inQuotes && s[i] == target {
				return i
			}
		}
	}
	return -1
}

func splitUnquoted(s string, sep byte) []string {
	var out []string
	start := 0
	inQuotes := false
	for i := 0; i < len(s); i++ {
		switch s[i] {
		case '"':
			inQuotes = !inQuotes
		case '\\':
			if inQuotes {
				i++
			}
		default:
			if !inQuotes && s[i] == sep {
				out = append(out, s[start:i])
				start = i + 1
			}
		}
	}
	out = append(out, s[start:])
	return out
}

func unquoteParam(s string) string {
	if len(s) >= 2 && s[0] == '"' && s[len(s)-1] == '"' {
		s = s[1 : len(s)-1]
	}
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] == '^' && i+1 < len(s) {
			switch s[i+1] {
			case '^':
				b.WriteByte('^')
				i++
				continue
			case 'n', 'N':
				b.WriteByte('\n')
				i++
				continue
			case '\'':
				b.WriteByte('"')
				i++
				continue
			}
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

// Encode serializes a component tree using CRLF line endings.
func (c *Component) Encode() string {
	var b strings.Builder
	c.encodeTo(&b)
	return b.String()
}

func (c *Component) encodeTo(b *strings.Builder) {
	b.WriteString("BEGIN:")
	b.WriteString(c.Name)
	b.WriteString("\r\n")
	for _, p := range c.Props {
		writeContentLine(b, p)
	}
	for _, ch := range c.Children {
		ch.encodeTo(b)
	}
	b.WriteString("END:")
	b.WriteString(c.Name)
	b.WriteString("\r\n")
}

func writeContentLine(b *strings.Builder, p Prop) {
	b.WriteString(p.Name)
	keys := make([]string, 0, len(p.Params))
	for k := range p.Params {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		vals := p.Params[k]
		if len(vals) == 0 {
			continue
		}
		b.WriteString(";")
		b.WriteString(k)
		b.WriteString("=")
		for i, v := range vals {
			if i > 0 {
				b.WriteString(",")
			}
			b.WriteString(quoteParam(v))
		}
	}
	b.WriteString(":")
	b.WriteString(p.Value)
	b.WriteString("\r\n")
}

func quoteParam(v string) string {
	needQuote := false
	for _, r := range v {
		if r == ':' || r == ';' || r == ',' || r == '"' {
			needQuote = true
			break
		}
	}
	v = strings.ReplaceAll(v, "^", "^^")
	v = strings.ReplaceAll(v, "\n", "^n")
	v = strings.ReplaceAll(v, "\"", "^'")
	if needQuote {
		return `"` + v + `"`
	}
	return v
}

// EscapeText escapes a TEXT property value.
func EscapeText(s string) string {
	s = strings.ReplaceAll(s, "\\", "\\\\")
	s = strings.ReplaceAll(s, ";", "\\;")
	s = strings.ReplaceAll(s, ",", "\\,")
	s = strings.ReplaceAll(s, "\r\n", "\\n")
	s = strings.ReplaceAll(s, "\n", "\\n")
	return s
}

// UnescapeText unescapes a TEXT property value.
func UnescapeText(s string) string {
	var b strings.Builder
	for i := 0; i < len(s); i++ {
		if s[i] == '\\' && i+1 < len(s) {
			switch s[i+1] {
			case 'n', 'N':
				b.WriteByte('\n')
			case '\\', ';', ',':
				b.WriteByte(s[i+1])
			default:
				b.WriteByte(s[i])
				b.WriteByte(s[i+1])
			}
			i++
			continue
		}
		b.WriteByte(s[i])
	}
	return b.String()
}

// ValidComponentType reports whether name is a calendar component type
// supported by CalDAV calendar collections.
func ValidComponentType(name string) bool {
	switch strings.ToUpper(name) {
	case "VEVENT", "VTODO", "VJOURNAL", "VFREEBUSY":
		return true
	}
	return false
}
