// Command caldav-free runs a self-hosted CalDAV server with an admin UI.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"caldav-free/internal/auth"
	"caldav-free/internal/dav"
	"caldav-free/internal/reminders"
	"caldav-free/internal/store"
	"caldav-free/internal/web"
)

func main() {
	var (
		addr        = flag.String("addr", envOr("CALDAV_ADDR", ":5232"), "HTTP listen address")
		dataDir     = flag.String("data", envOr("CALDAV_DATA", "./data"), "data directory")
		adminUser   = flag.String("admin-user", envOr("CALDAV_ADMIN_USER", "admin"), "bootstrap admin username")
		adminPass   = flag.String("admin-pass", envOr("CALDAV_ADMIN_PASSWORD", ""), "bootstrap admin password (generated when empty)")
		adminEmail  = flag.String("admin-email", envOr("CALDAV_ADMIN_EMAIL", ""), "bootstrap admin email")
		externalURL = flag.String("external-url", envOr("CALDAV_EXTERNAL_URL", ""), "public base URL, e.g. https://dav.example.com")
		caldavURL   = flag.String("caldav-url", envOr("CALDAV_PUBLIC_URL", ""), "CalDAV URL shown in the admin UI (defaults to the request origin)")
		tlsCert     = flag.String("tls-cert", "", "TLS certificate file (enables HTTPS)")
		tlsKey      = flag.String("tls-key", "", "TLS private key file")
		debug       = flag.Bool("debug", false, "enable debug logging")
		showVersion = flag.Bool("version", false, "print version and exit")
	)
	flag.Parse()

	if *showVersion {
		fmt.Println("caldav-free 1.0.0")
		return
	}

	level := slog.LevelInfo
	if *debug {
		level = slog.LevelDebug
	}
	logger := slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: level}))
	slog.SetDefault(logger)

	dbPath := *dataDir + "/caldav-free.db"
	st, err := store.Open(dbPath)
	if err != nil {
		logger.Error("failed to open database", "path", dbPath, "error", err)
		os.Exit(1)
	}
	defer st.Close()

	if err := bootstrapAdmin(st, *adminUser, *adminPass, *adminEmail, logger); err != nil {
		logger.Error("failed to bootstrap admin", "error", err)
		os.Exit(1)
	}

	davHandler := dav.New(st, logger)
	davHandler.ExternalURL = *externalURL
	webServer, err := web.New(st, davHandler, logger, *externalURL)
	if err != nil {
		logger.Error("failed to initialize admin UI", "error", err)
		os.Exit(1)
	}
	webServer.CalDAVURL = strings.TrimRight(*caldavURL, "/")

	mux := http.NewServeMux()
	// CalDAV endpoints. Method-specific patterns keep the admin UI on GET /.
	mux.Handle("PROPFIND /{$}", davHandler)
	mux.Handle("OPTIONS /{$}", davHandler)
	mux.Handle("/.well-known/caldav", davHandler)
	mux.Handle("/.well-known/caldav/", davHandler)
	mux.Handle("/caldav", davHandler)
	mux.Handle("/caldav/", davHandler)
	mux.Handle("/dav", davHandler)
	mux.Handle("/dav/", davHandler)
	mux.Handle("/principals", davHandler)
	mux.Handle("/principals/", davHandler)
	mux.Handle("/calendars", davHandler)
	mux.Handle("/calendars/", davHandler)
	webServer.Register(mux)

	handler := withLogging(logger, withRecovery(logger, mux))
	srv := &http.Server{
		Addr:              *addr,
		Handler:           handler,
		ReadHeaderTimeout: 15 * time.Second,
		IdleTimeout:       2 * time.Minute,
		MaxHeaderBytes:    1 << 20,
	}

	base := *externalURL
	if base == "" {
		base = "http://" + displayHost(*addr)
	}
	logger.Info("caldav-free starting",
		"addr", *addr,
		"data", dbPath,
		"caldav", base+"/calendars/",
		"admin", base+"/admin",
	)
	if !strings.HasPrefix(base, "https://") {
		logger.Warn("serving without HTTPS; CalDAV Basic Auth credentials will be sent in clear text unless a TLS proxy is used")
	}

	reminderCtx, stopReminders := context.WithCancel(context.Background())
	defer stopReminders()
	if os.Getenv("CALDAV_REMINDERS") != "off" {
		if scheduler, err := reminders.New(st, logger, base); err != nil {
			logger.Warn("reminder scheduler unavailable", "error", err)
		} else {
			go scheduler.Run(reminderCtx)
		}
	}

	errCh := make(chan error, 1)
	go func() {
		if *tlsCert != "" || *tlsKey != "" {
			if *tlsCert == "" || *tlsKey == "" {
				errCh <- errors.New("both -tls-cert and -tls-key are required")
				return
			}
			errCh <- srv.ListenAndServeTLS(*tlsCert, *tlsKey)
			return
		}
		errCh <- srv.ListenAndServe()
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)

	select {
	case err := <-errCh:
		if err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server stopped", "error", err)
			os.Exit(1)
		}
	case sig := <-stop:
		logger.Info("shutting down", "signal", sig.String())
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(ctx); err != nil {
			logger.Error("graceful shutdown failed", "error", err)
		}
	}
}

func bootstrapAdmin(st *store.Store, username, password, email string, logger *slog.Logger) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	count, err := st.CountUsers(ctx)
	if err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	username = strings.ToLower(strings.TrimSpace(username))
	if username == "" {
		username = "admin"
	}
	generated := false
	if password == "" {
		password = auth.RandomPassword()
		generated = true
	}
	if len(password) < 4 {
		return errors.New("admin password must be at least 4 characters")
	}
	if len(password) < 8 {
		logger.Warn("initial admin password is short; use a stronger password for any non-local deployment")
	}
	hash, err := auth.HashPassword(password)
	if err != nil {
		return err
	}
	if _, err := st.CreateUser(ctx, username, "Administrator", email, hash, true); err != nil {
		return err
	}
	logger.Info("created initial admin account", "username", username)
	if generated {
		fmt.Fprintf(os.Stdout, "\n  ┌─────────────────────────────────────────────┐\n"+
			"  │  Initial admin password (save it now):      │\n"+
			"  │  %-43s│\n"+
			"  └─────────────────────────────────────────────┘\n\n", password)
	}
	return nil
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func displayHost(addr string) string {
	if strings.HasPrefix(addr, ":") {
		return "localhost" + addr
	}
	if strings.HasPrefix(addr, "0.0.0.0:") {
		return "localhost:" + strings.TrimPrefix(addr, "0.0.0.0:")
	}
	return addr
}

type statusRecorder struct {
	http.ResponseWriter
	status int
	bytes  int
}

func (r *statusRecorder) WriteHeader(code int) {
	r.status = code
	r.ResponseWriter.WriteHeader(code)
}

func (r *statusRecorder) Write(data []byte) (int, error) {
	if r.status == 0 {
		r.status = http.StatusOK
	}
	n, err := r.ResponseWriter.Write(data)
	r.bytes += n
	return n, err
}

func withRecovery(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if rec := recover(); rec != nil {
				logger.Error("panic recovered", "method", r.Method, "path", r.URL.Path, "panic", rec)
				http.Error(w, "internal server error", http.StatusInternalServerError)
			}
		}()
		next.ServeHTTP(w, r)
	})
}

func withLogging(logger *slog.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w}
		next.ServeHTTP(rec, r)
		status := rec.status
		if status == 0 {
			status = http.StatusOK
		}
		level := slog.LevelInfo
		if r.URL.Path == "/healthz" {
			level = slog.LevelDebug
		}
		logger.Log(r.Context(), level, "request",
			"method", r.Method,
			"path", r.URL.Path,
			"status", status,
			"bytes", rec.bytes,
			"duration", time.Since(start).Round(time.Millisecond).String(),
			"remote", clientAddr(r),
		)
	})
}

func clientAddr(r *http.Request) string {
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		if i := strings.IndexByte(fwd, ','); i >= 0 {
			return strings.TrimSpace(fwd[:i])
		}
		return strings.TrimSpace(fwd)
	}
	return r.RemoteAddr
}
