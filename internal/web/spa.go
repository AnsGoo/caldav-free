package web

import (
	"embed"
	"io/fs"
	"mime"
	"net/http"
	"path"
	"strings"
)

//go:embed all:dist
var spaDist embed.FS

func (s *Server) spaHandler() http.Handler {
	sub, err := fs.Sub(spaDist, "dist")
	if err != nil {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "admin UI is not built", http.StatusInternalServerError)
		})
	}
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet && r.Method != http.MethodHead {
			http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
			return
		}
		if r.URL.Path == "/admin" {
			http.Redirect(w, r, "/admin/", http.StatusMovedPermanently)
			return
		}
		rel := strings.TrimPrefix(r.URL.Path, "/admin/")
		rel = strings.TrimPrefix(rel, "/")
		if rel != "" && !strings.Contains(rel, "..") {
			if data, err := fs.ReadFile(sub, rel); err == nil {
				if ext := path.Ext(rel); ext != "" {
					ct := mime.TypeByExtension(ext)
					if ext == ".webmanifest" {
						ct = "application/manifest+json"
						// 清单必须每次新鲜获取：部分代理/浏览器会缓存错误的 HTML 响应，
						// 导致 Chrome 报 “Manifest: Line: 1, column: 1, Syntax error”。
						w.Header().Set("Cache-Control", "no-store, max-age=0")
					}
					if ct != "" {
						w.Header().Set("Content-Type", ct)
					}
				}
				if strings.HasPrefix(rel, "assets/") {
					w.Header().Set("Cache-Control", "public, max-age=31536000, immutable")
				} else if path.Ext(rel) != ".webmanifest" {
					w.Header().Set("Cache-Control", "no-cache")
				}
				w.WriteHeader(http.StatusOK)
				if r.Method != http.MethodHead {
					_, _ = w.Write(data)
				}
				return
			}
			if strings.HasPrefix(rel, "assets/") || strings.Contains(path.Base(rel), ".") {
				http.NotFound(w, r)
				return
			}
		}
		index, err := fs.ReadFile(sub, "index.html")
		if err != nil {
			http.Error(w, "admin UI is not built", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		w.Header().Set("Cache-Control", "no-cache")
		w.WriteHeader(http.StatusOK)
		if r.Method != http.MethodHead {
			_, _ = w.Write(index)
		}
	})
}
