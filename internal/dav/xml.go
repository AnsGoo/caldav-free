package dav

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"strings"
)

const (
	nsDAV    = "DAV:"
	nsCalDAV = "urn:ietf:params:xml:ns:caldav"
	nsCS     = "http://calendarserver.org/ns/"
	nsApple  = "http://apple.com/ns/ical/"
)

// node is a small XML tree used to render WebDAV responses safely.
type node struct {
	Name     xml.Name
	Attrs    []xml.Attr
	Text     string
	Children []node
}

func el(space, local string, children ...node) node {
	return node{Name: xml.Name{Space: space, Local: local}, Children: children}
}

func txt(space, local, text string) node {
	return node{Name: xml.Name{Space: space, Local: local}, Text: text}
}

func attr(local, value string) xml.Attr {
	return xml.Attr{Name: xml.Name{Local: local}, Value: value}
}

func (n node) encode(enc *xml.Encoder) error {
	return n.encodeNS(enc, "")
}

// encodeNS elides redundant default namespace declarations, producing cleaner
// XML while keeping every element in the correct namespace.
func (n node) encodeNS(enc *xml.Encoder, inherited string) error {
	name := n.Name
	next := inherited
	if name.Space == inherited {
		name.Space = ""
	} else {
		next = name.Space
	}
	start := xml.StartElement{Name: name, Attr: n.Attrs}
	if err := enc.EncodeToken(start); err != nil {
		return err
	}
	if n.Text != "" {
		if err := enc.EncodeToken(xml.CharData(n.Text)); err != nil {
			return err
		}
	}
	for _, child := range n.Children {
		if err := child.encodeNS(enc, next); err != nil {
			return err
		}
	}
	return enc.EncodeToken(start.End())
}

func marshalNode(n node) ([]byte, error) {
	var buf bytes.Buffer
	buf.WriteString(xml.Header)
	enc := xml.NewEncoder(&buf)
	enc.Indent("", "")
	if err := n.encode(enc); err != nil {
		return nil, err
	}
	if err := enc.Flush(); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

type propResult struct {
	Name   xml.Name
	Value  *node
	Status int
}

type davResponse struct {
	Href   string
	Props  []propResult
	Status int
}

func statusText(code int) string {
	if t := http.StatusText(code); t != "" {
		return fmt.Sprintf("HTTP/1.1 %d %s", code, t)
	}
	return fmt.Sprintf("HTTP/1.1 %d", code)
}

func buildMultistatus(responses []davResponse, extra ...node) node {
	respNodes := make([]node, 0, len(responses))
	for _, res := range responses {
		children := []node{txt(nsDAV, "href", res.Href)}
		if res.Status != 0 {
			children = append(children, txt(nsDAV, "status", statusText(res.Status)))
		}
		if len(res.Props) > 0 {
			grouped := map[int][]node{}
			order := []int{}
			for _, p := range res.Props {
				status := p.Status
				if status == 0 {
					status = http.StatusOK
				}
				if _, seen := grouped[status]; !seen {
					order = append(order, status)
				}
				if p.Value != nil {
					grouped[status] = append(grouped[status], *p.Value)
				} else {
					grouped[status] = append(grouped[status], el(p.Name.Space, p.Name.Local))
				}
			}
			for _, status := range order {
				if len(grouped[status]) == 0 {
					continue
				}
				children = append(children, el(nsDAV, "propstat",
					el(nsDAV, "prop", grouped[status]...),
					txt(nsDAV, "status", statusText(status)),
				))
			}
		}
		respNodes = append(respNodes, el(nsDAV, "response", children...))
	}
	root := el(nsDAV, "multistatus", respNodes...)
	root.Children = append(root.Children, extra...)
	return root
}

func writeXML(w http.ResponseWriter, status int, root node) {
	data, err := marshalNode(root)
	if err != nil {
		http.Error(w, "failed to encode XML response", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/xml; charset=utf-8")
	w.Header().Set("Content-Length", fmt.Sprint(len(data)))
	w.WriteHeader(status)
	_, _ = w.Write(data)
}

func writeMultistatus(w http.ResponseWriter, responses []davResponse, extra ...node) {
	writeXML(w, http.StatusMultiStatus, buildMultistatus(responses, extra...))
}

func writeDAVError(w http.ResponseWriter, status int, children ...node) {
	writeXML(w, status, el(nsDAV, "error", children...))
}

func davError(space, local string) node { return el(space, local) }

// ---------------------------------------------------------------- requests

type propfindReq struct {
	AllProp  bool
	PropName bool
	Props    []xml.Name
	Include  []xml.Name
}

type propElement struct {
	XMLName  xml.Name
	InnerXML string `xml:",innerxml"`
}

type propContainer struct {
	Props []propElement `xml:",any"`
}

func (p *propContainer) names() []xml.Name {
	if p == nil {
		return nil
	}
	out := make([]xml.Name, 0, len(p.Props))
	for _, prop := range p.Props {
		out = append(out, prop.XMLName)
	}
	return out
}

func parsePropfind(data []byte) (propfindReq, error) {
	req := propfindReq{}
	if len(bytes.TrimSpace(data)) == 0 {
		req.AllProp = true
		return req, nil
	}
	var doc struct {
		XMLName  xml.Name
		AllProp  *struct{}      `xml:"DAV: allprop"`
		PropName *struct{}      `xml:"DAV: propname"`
		Prop     *propContainer `xml:"DAV: prop"`
		Include  *propContainer `xml:"DAV: include"`
	}
	dec := xml.NewDecoder(bytes.NewReader(data))
	if err := dec.Decode(&doc); err != nil {
		return req, fmt.Errorf("invalid PROPFIND body: %w", err)
	}
	if doc.XMLName.Local != "propfind" {
		return req, fmt.Errorf("expected propfind, got %s", doc.XMLName.Local)
	}
	req.AllProp = doc.AllProp != nil
	req.PropName = doc.PropName != nil
	if doc.Prop != nil {
		req.Props = doc.Prop.names()
	}
	if doc.Include != nil {
		req.Include = doc.Include.names()
	}
	if !req.AllProp && !req.PropName && len(req.Props) == 0 {
		req.AllProp = true
	}
	return req, nil
}

func readBody(w http.ResponseWriter, r *http.Request, limit int64) ([]byte, bool) {
	body, err := io.ReadAll(io.LimitReader(r.Body, limit+1))
	if err != nil {
		http.Error(w, "failed to read request body", http.StatusBadRequest)
		return nil, false
	}
	if int64(len(body)) > limit {
		http.Error(w, "request body too large", http.StatusRequestEntityTooLarge)
		return nil, false
	}
	return body, true
}

func splitETags(header string) []string {
	if strings.TrimSpace(header) == "" {
		return nil
	}
	parts := strings.Split(header, ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		p = strings.TrimSpace(p)
		p = strings.TrimPrefix(p, "W/")
		p = strings.Trim(p, `"`)
		if p != "" {
			out = append(out, p)
		}
	}
	return out
}

// matchesETag implements If-Match / If-None-Match against a stored raw etag.
func matchesETag(header, etag string, exists bool) bool {
	header = strings.TrimSpace(header)
	if header == "" {
		return true
	}
	if header == "*" {
		return exists
	}
	for _, candidate := range splitETags(header) {
		if candidate == etag {
			return true
		}
	}
	return false
}
