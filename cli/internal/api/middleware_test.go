package api

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/go-chi/chi/v5"
)

func TestRequestIDMiddleware(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		reqID := GetRequestID(r.Context())
		if reqID == "" {
			t.Error("expected request ID to be set")
		}
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(requestIDMiddleware)
	r.Get("/", handler)

	req := httptest.NewRequest("GET", "/", http.NoBody)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	// Check response header
	if w.Header().Get("X-Request-ID") == "" {
		t.Error("expected X-Request-ID header to be set")
	}
}

func TestRealIPMiddleware(t *testing.T) {
	tests := []struct {
		name       string
		headers    map[string]string
		remoteAddr string
		expectedIP string
	}{
		{
			name:       "X-Forwarded-For single IP",
			headers:    map[string]string{"X-Forwarded-For": "1.2.3.4"},
			remoteAddr: "192.168.1.1:12345",
			expectedIP: "1.2.3.4",
		},
		{
			name:       "X-Forwarded-For multiple IPs",
			headers:    map[string]string{"X-Forwarded-For": "1.2.3.4, 5.6.7.8"},
			remoteAddr: "192.168.1.1:12345",
			expectedIP: "1.2.3.4",
		},
		{
			name:       "X-Real-IP",
			headers:    map[string]string{"X-Real-IP": "10.0.0.1"},
			remoteAddr: "192.168.1.1:12345",
			expectedIP: "10.0.0.1",
		},
		{
			name:       "X-Forwarded-For takes precedence over X-Real-IP",
			headers:    map[string]string{"X-Forwarded-For": "1.2.3.4", "X-Real-IP": "10.0.0.1"},
			remoteAddr: "192.168.1.1:12345",
			expectedIP: "1.2.3.4",
		},
		{
			name:       "fallback to RemoteAddr",
			headers:    map[string]string{},
			remoteAddr: "192.168.1.1:12345",
			expectedIP: "192.168.1.1",
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				clientIP := GetClientIP(r.Context())
				if clientIP != tc.expectedIP {
					t.Errorf("expected client IP %q, got %q", tc.expectedIP, clientIP)
				}
				w.WriteHeader(http.StatusOK)
			})

			r := chi.NewRouter()
			r.Use(realIPMiddleware)
			r.Get("/", handler)

			req := httptest.NewRequest("GET", "/", http.NoBody)
			req.RemoteAddr = tc.remoteAddr
			for k, v := range tc.headers {
				req.Header.Set(k, v)
			}
			w := httptest.NewRecorder()

			r.ServeHTTP(w, req)
		})
	}
}

func TestLoggerMiddleware(t *testing.T) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, nil))

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware) // Need this to set client IP
	r.Use(loggerMiddleware(logger))
	r.Get("/test/path", handler)

	req := httptest.NewRequest("GET", "/test/path", http.NoBody)
	req.RemoteAddr = "10.0.0.1:12345"
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	// Parse log output
	var logEntry map[string]interface{}
	if err := json.Unmarshal(buf.Bytes(), &logEntry); err != nil {
		t.Fatalf("failed to parse log output: %v", err)
	}

	// Verify log fields
	if logEntry["msg"] != "request completed" {
		t.Errorf("expected msg 'request completed', got %q", logEntry["msg"])
	}
	if logEntry["method"] != "GET" {
		t.Errorf("expected method 'GET', got %q", logEntry["method"])
	}
	if logEntry["path"] != "/test/path" {
		t.Errorf("expected path '/test/path', got %q", logEntry["path"])
	}
	if status, ok := logEntry["status"].(float64); !ok || int(status) != 200 {
		t.Errorf("expected status 200, got %v", logEntry["status"])
	}
	if logEntry["client_ip"] != "10.0.0.1" {
		t.Errorf("expected client_ip '10.0.0.1', got %q", logEntry["client_ip"])
	}
	if _, ok := logEntry["duration_ms"]; !ok {
		t.Error("expected duration_ms to be present")
	}
}

func TestRecoverMiddleware(t *testing.T) {
	var buf bytes.Buffer
	logger := slog.New(slog.NewJSONHandler(&buf, nil))

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		panic("test panic")
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware)
	r.Use(recoverMiddleware(logger))
	r.Get("/", handler)

	req := httptest.NewRequest("GET", "/", http.NoBody)
	w := httptest.NewRecorder()

	// Should not panic
	r.ServeHTTP(w, req)

	// Should return 500
	if w.Code != http.StatusInternalServerError {
		t.Errorf("expected status %d, got %d", http.StatusInternalServerError, w.Code)
	}

	// Should log the panic
	if !strings.Contains(buf.String(), "panic recovered") {
		t.Error("expected log to contain 'panic recovered'")
	}

	// Check response body
	var resp map[string]string
	if err := json.Unmarshal(w.Body.Bytes(), &resp); err != nil {
		t.Fatalf("failed to parse response: %v", err)
	}
	if resp["error"] != "internal server error" {
		t.Errorf("expected error 'internal server error', got %q", resp["error"])
	}
}

func TestTimeoutMiddleware(t *testing.T) {
	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ctx := r.Context()
		deadline, ok := ctx.Deadline()
		if !ok {
			t.Error("expected context to have deadline")
			return
		}
		// Deadline should be roughly 100ms from now
		remaining := time.Until(deadline)
		if remaining < 50*time.Millisecond || remaining > 150*time.Millisecond {
			t.Errorf("unexpected deadline remaining: %v", remaining)
		}
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(timeoutMiddleware(100 * time.Millisecond))
	r.Get("/", handler)

	req := httptest.NewRequest("GET", "/", http.NoBody)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("expected status %d, got %d", http.StatusOK, w.Code)
	}
}

func TestCORSMiddleware(t *testing.T) {
	tests := []struct {
		name           string
		origin         string
		shouldAllow    bool
		allowLocalhost bool
	}{
		{
			name:           "production origin oakcompendium.org",
			origin:         "https://oakcompendium.org",
			shouldAllow:    true,
			allowLocalhost: true,
		},
		{
			name:           "production origin oakcompendium.com",
			origin:         "https://oakcompendium.com",
			shouldAllow:    true,
			allowLocalhost: true,
		},
		{
			name:           "localhost with port 3000",
			origin:         "http://localhost:3000",
			shouldAllow:    true,
			allowLocalhost: true,
		},
		{
			name:           "localhost with port 5173",
			origin:         "http://localhost:5173",
			shouldAllow:    true,
			allowLocalhost: true,
		},
		{
			name:           "localhost disabled",
			origin:         "http://localhost:3000",
			shouldAllow:    false,
			allowLocalhost: false,
		},
		{
			name:           "unauthorized origin",
			origin:         "https://example.com",
			shouldAllow:    false,
			allowLocalhost: true,
		},
		{
			name:           "http on production domain",
			origin:         "http://oakcompendium.org",
			shouldAllow:    false,
			allowLocalhost: true,
		},
	}

	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
				w.WriteHeader(http.StatusOK)
			})

			config := CORSConfig{
				AllowedOrigins: []string{
					"https://oakcompendium.org",
					"https://oakcompendium.com",
				},
				AllowLocalhost: tc.allowLocalhost,
			}

			r := chi.NewRouter()
			r.Use(corsMiddleware(config))
			r.Get("/", handler)

			// Test preflight OPTIONS request
			req := httptest.NewRequest("OPTIONS", "/", http.NoBody)
			req.Header.Set("Origin", tc.origin)
			req.Header.Set("Access-Control-Request-Method", "GET")
			w := httptest.NewRecorder()

			r.ServeHTTP(w, req)

			allowOrigin := w.Header().Get("Access-Control-Allow-Origin")
			if tc.shouldAllow && allowOrigin == "" {
				t.Errorf("expected origin %q to be allowed", tc.origin)
			}
			if !tc.shouldAllow && allowOrigin != "" {
				t.Errorf("expected origin %q to be blocked, but got Allow-Origin: %q", tc.origin, allowOrigin)
			}
		})
	}
}

func TestConditionalRateLimitMiddleware_HealthExempt(t *testing.T) {
	config := RateLimitConfig{
		ReadLimit:    1, // Very low limit
		WriteLimit:   1,
		BackupLimit:  1,
		Window:       time.Second,
		BackupWindow: time.Minute,
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware)
	r.Use(conditionalRateLimitMiddleware(config))
	r.Get("/health", handler)
	r.Get("/health/ready", handler)

	// Make many requests to health endpoints - they should all succeed
	for i := range 20 {
		req := httptest.NewRequest("GET", "/health", http.NoBody)
		req.RemoteAddr = "1.2.3.4:12345"
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("health endpoint request %d should not be rate limited, got status %d", i, w.Code)
		}
	}

	for i := range 20 {
		req := httptest.NewRequest("GET", "/health/ready", http.NoBody)
		req.RemoteAddr = "1.2.3.4:12345"
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("health/ready endpoint request %d should not be rate limited, got status %d", i, w.Code)
		}
	}
}

func TestConditionalRateLimitMiddleware_ReadLimit(t *testing.T) {
	config := RateLimitConfig{
		ReadLimit:    2, // Allow 2 requests per window
		WriteLimit:   5,
		BackupLimit:  1,
		Window:       time.Second,
		BackupWindow: time.Minute,
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware)
	r.Use(conditionalRateLimitMiddleware(config))
	r.Get("/api/v1/species", handler)

	// First 2 requests should succeed
	for i := range 2 {
		req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
		req.RemoteAddr = "1.2.3.4:12345"
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("request %d should succeed, got status %d", i, w.Code)
		}
	}

	// Third request should be rate limited
	req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
	req.RemoteAddr = "1.2.3.4:12345"
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("third request should be rate limited, got status %d", w.Code)
	}

	// Different IP should not be affected
	req = httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
	req.RemoteAddr = "5.6.7.8:12345"
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("different IP should not be rate limited, got status %d", w.Code)
	}
}

func TestConditionalRateLimitMiddleware_WriteLimit(t *testing.T) {
	config := RateLimitConfig{
		ReadLimit:    10,
		WriteLimit:   2, // Allow 2 write requests per window
		BackupLimit:  1,
		Window:       time.Second,
		BackupWindow: time.Minute,
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware)
	r.Use(conditionalRateLimitMiddleware(config))
	r.Post("/api/v1/species", handler)
	r.Put("/api/v1/species/alba", handler)
	r.Delete("/api/v1/species/alba", handler)

	// First 2 write requests should succeed
	for i := range 2 {
		req := httptest.NewRequest("POST", "/api/v1/species", http.NoBody)
		req.RemoteAddr = "1.2.3.4:12345"
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)

		if w.Code != http.StatusOK {
			t.Errorf("write request %d should succeed, got status %d", i, w.Code)
		}
	}

	// Third write request should be rate limited
	req := httptest.NewRequest("PUT", "/api/v1/species/alba", http.NoBody)
	req.RemoteAddr = "1.2.3.4:12345"
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("third write request should be rate limited, got status %d", w.Code)
	}
}

func TestConditionalRateLimitMiddleware_BackupLimit(t *testing.T) {
	config := RateLimitConfig{
		ReadLimit:    10,
		WriteLimit:   10,
		BackupLimit:  1, // Allow 1 backup request per window
		Window:       time.Second,
		BackupWindow: time.Second, // Use short window for testing
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware)
	r.Use(conditionalRateLimitMiddleware(config))
	r.Get("/api/v1/backup", handler)

	// First backup request should succeed
	req := httptest.NewRequest("GET", "/api/v1/backup", http.NoBody)
	req.RemoteAddr = "1.2.3.4:12345"
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusOK {
		t.Errorf("first backup request should succeed, got status %d", w.Code)
	}

	// Second backup request should be rate limited
	req = httptest.NewRequest("GET", "/api/v1/backup", http.NoBody)
	req.RemoteAddr = "1.2.3.4:12345"
	w = httptest.NewRecorder()
	r.ServeHTTP(w, req)

	if w.Code != http.StatusTooManyRequests {
		t.Errorf("second backup request should be rate limited, got status %d", w.Code)
	}
}

func TestIsHealthEndpoint(t *testing.T) {
	tests := []struct {
		path     string
		expected bool
	}{
		{"/health", true},
		{"/health/ready", true},
		{"/healthcheck", false},
		{"/api/v1/health", false},
		{"/api/v1/species", false},
	}

	for _, tc := range tests {
		t.Run(tc.path, func(t *testing.T) {
			result := isHealthEndpoint(tc.path)
			if result != tc.expected {
				t.Errorf("isHealthEndpoint(%q) = %v, expected %v", tc.path, result, tc.expected)
			}
		})
	}
}

func TestIsWriteMethod(t *testing.T) {
	tests := []struct {
		method   string
		expected bool
	}{
		{"GET", false},
		{"HEAD", false},
		{"OPTIONS", false},
		{"POST", true},
		{"PUT", true},
		{"DELETE", true},
		{"PATCH", true},
	}

	for _, tc := range tests {
		t.Run(tc.method, func(t *testing.T) {
			result := isWriteMethod(tc.method)
			if result != tc.expected {
				t.Errorf("isWriteMethod(%q) = %v, expected %v", tc.method, result, tc.expected)
			}
		})
	}
}

func TestIsBackupEndpoint(t *testing.T) {
	tests := []struct {
		path     string
		expected bool
	}{
		{"/api/v1/backup", true},
		{"/api/v1/backup/latest", true},
		{"/api/v1/species", false},
		{"/backup", false},
	}

	for _, tc := range tests {
		t.Run(tc.path, func(t *testing.T) {
			result := isBackupEndpoint(tc.path)
			if result != tc.expected {
				t.Errorf("isBackupEndpoint(%q) = %v, expected %v", tc.path, result, tc.expected)
			}
		})
	}
}

func TestContextHelpers(t *testing.T) {
	t.Run("GetRequestID with value", func(t *testing.T) {
		ctx := context.WithValue(context.Background(), RequestIDKey, "test-id-123")
		result := GetRequestID(ctx)
		if result != "test-id-123" {
			t.Errorf("expected 'test-id-123', got %q", result)
		}
	})

	t.Run("GetRequestID without value", func(t *testing.T) {
		result := GetRequestID(context.Background())
		if result != "" {
			t.Errorf("expected empty string, got %q", result)
		}
	})

	t.Run("GetClientIP with value", func(t *testing.T) {
		ctx := context.WithValue(context.Background(), ClientIPKey, "1.2.3.4")
		result := GetClientIP(ctx)
		if result != "1.2.3.4" {
			t.Errorf("expected '1.2.3.4', got %q", result)
		}
	})

	t.Run("GetClientIP without value", func(t *testing.T) {
		result := GetClientIP(context.Background())
		if result != "" {
			t.Errorf("expected empty string, got %q", result)
		}
	})
}

func TestDefaultConfigs(t *testing.T) {
	t.Run("DefaultRateLimitConfig", func(t *testing.T) {
		config := DefaultRateLimitConfig()
		if config.ReadLimit != 10 {
			t.Errorf("expected ReadLimit 10, got %d", config.ReadLimit)
		}
		if config.WriteLimit != 5 {
			t.Errorf("expected WriteLimit 5, got %d", config.WriteLimit)
		}
		if config.BackupLimit != 1 {
			t.Errorf("expected BackupLimit 1, got %d", config.BackupLimit)
		}
		if config.Window != time.Second {
			t.Errorf("expected Window 1s, got %v", config.Window)
		}
		if config.BackupWindow != time.Minute {
			t.Errorf("expected BackupWindow 1m, got %v", config.BackupWindow)
		}
	})

	t.Run("DefaultCORSConfig", func(t *testing.T) {
		config := DefaultCORSConfig()
		if len(config.AllowedOrigins) != 2 {
			t.Errorf("expected 2 allowed origins, got %d", len(config.AllowedOrigins))
		}
		if !config.AllowLocalhost {
			t.Error("expected AllowLocalhost to be true")
		}
	})

	t.Run("DefaultMiddlewareConfig", func(t *testing.T) {
		config := DefaultMiddlewareConfig(nil)
		if config.Logger == nil {
			t.Error("expected logger to be set")
		}
		if config.Timeout != 30*time.Second {
			t.Errorf("expected Timeout 30s, got %v", config.Timeout)
		}
	})
}

func TestResponseWriter(t *testing.T) {
	t.Run("captures status code", func(t *testing.T) {
		rec := httptest.NewRecorder()
		rw := wrapResponseWriter(rec)

		rw.WriteHeader(http.StatusCreated)

		if rw.status != http.StatusCreated {
			t.Errorf("expected status %d, got %d", http.StatusCreated, rw.status)
		}
	})

	t.Run("defaults to 200", func(t *testing.T) {
		rec := httptest.NewRecorder()
		rw := wrapResponseWriter(rec)

		if rw.status != http.StatusOK {
			t.Errorf("expected default status %d, got %d", http.StatusOK, rw.status)
		}
	})

	t.Run("Write sets status 200 implicitly", func(t *testing.T) {
		rec := httptest.NewRecorder()
		rw := wrapResponseWriter(rec)

		rw.Write([]byte("hello"))

		if rw.status != http.StatusOK {
			t.Errorf("expected status %d after Write, got %d", http.StatusOK, rw.status)
		}
	})

	t.Run("WriteHeader only called once", func(t *testing.T) {
		rec := httptest.NewRecorder()
		rw := wrapResponseWriter(rec)

		rw.WriteHeader(http.StatusCreated)
		rw.WriteHeader(http.StatusNotFound) // Should be ignored

		if rw.status != http.StatusCreated {
			t.Errorf("expected status %d, got %d", http.StatusCreated, rw.status)
		}
	})
}

func TestSetupMiddleware(t *testing.T) {
	// Test that SetupMiddleware can be called without panicking
	r := chi.NewRouter()
	s := &Server{
		router: r,
		logger: slog.Default(),
	}

	config := DefaultMiddlewareConfig(nil)
	s.SetupMiddleware(config)

	// Verify middleware is applied by making a request
	r.Get("/test", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	req := httptest.NewRequest("GET", "/test", http.NoBody)
	w := httptest.NewRecorder()

	r.ServeHTTP(w, req)

	// Should have X-Request-ID header from middleware
	if w.Header().Get("X-Request-ID") == "" {
		t.Error("expected X-Request-ID header to be set by middleware")
	}
}

func TestConcurrentRateLimiting(t *testing.T) {
	config := RateLimitConfig{
		ReadLimit:    5,
		WriteLimit:   5,
		BackupLimit:  1,
		Window:       time.Second,
		BackupWindow: time.Minute,
	}

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	r := chi.NewRouter()
	r.Use(realIPMiddleware)
	r.Use(conditionalRateLimitMiddleware(config))
	r.Get("/api/v1/species", handler)

	// Make concurrent requests
	var wg sync.WaitGroup
	results := make(chan int, 20)

	for range 20 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			req := httptest.NewRequest("GET", "/api/v1/species", http.NoBody)
			req.RemoteAddr = "1.2.3.4:12345"
			w := httptest.NewRecorder()
			r.ServeHTTP(w, req)
			results <- w.Code
		}()
	}

	wg.Wait()
	close(results)

	// Count results
	var okCount, rateLimitedCount int
	for code := range results {
		if code == http.StatusOK {
			okCount++
		} else if code == http.StatusTooManyRequests {
			rateLimitedCount++
		}
	}

	// Should have some successful and some rate limited
	if okCount == 0 {
		t.Error("expected at least some successful requests")
	}
	if rateLimitedCount == 0 {
		t.Error("expected at least some rate limited requests")
	}
	if okCount+rateLimitedCount != 20 {
		t.Errorf("expected 20 total responses, got %d", okCount+rateLimitedCount)
	}
}
