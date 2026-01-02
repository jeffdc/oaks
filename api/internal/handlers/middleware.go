package handlers

import (
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
	"github.com/go-chi/httprate"
)

// Context keys for middleware values
type contextKey string

const (
	// RequestIDKey is the context key for the request ID
	RequestIDKey contextKey = "request_id"
	// ClientIPKey is the context key for the client IP address
	ClientIPKey contextKey = "client_ip"
)

// RateLimitConfig holds rate limiting configuration
type RateLimitConfig struct {
	ReadLimit    int           // requests per window for GET
	WriteLimit   int           // requests per window for POST/PUT/DELETE
	BackupLimit  int           // requests per window for backup endpoints
	Window       time.Duration // rate limit window duration
	BackupWindow time.Duration // backup endpoint window duration
}

// DefaultRateLimitConfig returns the default rate limiting configuration
func DefaultRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		ReadLimit:    10, // 10 req/sec
		WriteLimit:   5,  // 5 req/sec
		BackupLimit:  1,  // 1 req/min
		Window:       time.Second,
		BackupWindow: time.Minute,
	}
}

// CORSConfig holds CORS configuration
type CORSConfig struct {
	AllowedOrigins []string
	AllowLocalhost bool // allow any localhost port in development
}

// DefaultCORSConfig returns the default CORS configuration
func DefaultCORSConfig() CORSConfig {
	return CORSConfig{
		AllowedOrigins: []string{
			"https://oakcompendium.org",
			"https://oakcompendium.com",
		},
		AllowLocalhost: true,
	}
}

// MiddlewareConfig holds all middleware configuration
type MiddlewareConfig struct {
	Logger    *slog.Logger
	RateLimit RateLimitConfig
	CORS      CORSConfig
	Timeout   time.Duration
}

// DefaultMiddlewareConfig returns the default middleware configuration
func DefaultMiddlewareConfig(logger *slog.Logger) MiddlewareConfig {
	if logger == nil {
		logger = slog.Default()
	}
	return MiddlewareConfig{
		Logger:    logger,
		RateLimit: DefaultRateLimitConfig(),
		CORS:      DefaultCORSConfig(),
		Timeout:   30 * time.Second,
	}
}

// GetRequestID returns the request ID from the context
func GetRequestID(ctx context.Context) string {
	if id, ok := ctx.Value(RequestIDKey).(string); ok {
		return id
	}
	return ""
}

// GetClientIP returns the client IP from the context
func GetClientIP(ctx context.Context) string {
	if ip, ok := ctx.Value(ClientIPKey).(string); ok {
		return ip
	}
	return ""
}

// requestIDMiddleware generates a unique request ID and adds it to the context
func requestIDMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Use chi's RequestID middleware to generate the ID
		requestID := middleware.GetReqID(r.Context())
		if requestID == "" {
			// Fallback: generate a simple ID if chi's middleware hasn't run
			requestID = generateRequestID()
		}

		// Add to context with our key
		ctx := context.WithValue(r.Context(), RequestIDKey, requestID)

		// Add to response header
		w.Header().Set("X-Request-ID", requestID)

		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// generateRequestID generates a simple request ID
func generateRequestID() string {
	return time.Now().Format("20060102150405.000000")
}

// realIPMiddleware extracts the real client IP from headers
func realIPMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Try X-Forwarded-For first (may contain multiple IPs, take first)
		ip := r.Header.Get("X-Forwarded-For")
		if ip != "" {
			// X-Forwarded-For may contain comma-separated list
			if idx := strings.Index(ip, ","); idx > 0 {
				ip = strings.TrimSpace(ip[:idx])
			}
		}

		// Try X-Real-IP if X-Forwarded-For is not set
		if ip == "" {
			ip = r.Header.Get("X-Real-IP")
		}

		// Fall back to RemoteAddr
		if ip == "" {
			ip = r.RemoteAddr
			// Remove port from RemoteAddr if present
			if idx := strings.LastIndex(ip, ":"); idx > 0 {
				// Check if this is an IPv6 address
				if strings.Count(ip, ":") == 1 {
					ip = ip[:idx]
				}
			}
		}

		ctx := context.WithValue(r.Context(), ClientIPKey, ip)
		next.ServeHTTP(w, r.WithContext(ctx))
	})
}

// responseWriter wraps http.ResponseWriter to capture status code
type responseWriter struct {
	http.ResponseWriter
	status      int
	wroteHeader bool
}

func wrapResponseWriter(w http.ResponseWriter) *responseWriter {
	return &responseWriter{ResponseWriter: w, status: http.StatusOK}
}

func (rw *responseWriter) WriteHeader(code int) {
	if !rw.wroteHeader {
		rw.status = code
		rw.wroteHeader = true
		rw.ResponseWriter.WriteHeader(code)
	}
}

func (rw *responseWriter) Write(b []byte) (int, error) {
	if !rw.wroteHeader {
		rw.WriteHeader(http.StatusOK)
	}
	return rw.ResponseWriter.Write(b)
}

// loggerMiddleware logs requests with structured slog output
func loggerMiddleware(logger *slog.Logger) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()

			wrapped := wrapResponseWriter(w)

			next.ServeHTTP(wrapped, r)

			duration := time.Since(start)

			logger.Info("request completed",
				"request_id", GetRequestID(r.Context()),
				"method", r.Method,
				"path", r.URL.Path,
				"status", wrapped.status,
				"duration_ms", duration.Milliseconds(),
				"client_ip", GetClientIP(r.Context()),
			)
		})
	}
}

// recoverMiddleware recovers from panics and logs them
func recoverMiddleware(logger *slog.Logger) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			defer func() {
				if err := recover(); err != nil {
					logger.Error("panic recovered",
						"request_id", GetRequestID(r.Context()),
						"error", err,
						"method", r.Method,
						"path", r.URL.Path,
						"client_ip", GetClientIP(r.Context()),
					)

					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusInternalServerError)
					_, _ = w.Write([]byte(`{"error":"internal server error"}`))
				}
			}()

			next.ServeHTTP(w, r)
		})
	}
}

// timeoutMiddleware adds a timeout to the request context
func timeoutMiddleware(timeout time.Duration) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			ctx, cancel := context.WithTimeout(r.Context(), timeout)
			defer cancel()

			next.ServeHTTP(w, r.WithContext(ctx))
		})
	}
}

// maxBodySize is the maximum allowed request body size (1MB)
const maxBodySize = 1 << 20 // 1MB

// bodySizeLimitMiddleware limits the size of request bodies to prevent memory exhaustion
func bodySizeLimitMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Only limit body size for methods that may have a body
		if r.Method == "POST" || r.Method == "PUT" || r.Method == "PATCH" {
			r.Body = http.MaxBytesReader(w, r.Body, maxBodySize)
		}
		next.ServeHTTP(w, r)
	})
}

// securityHeadersMiddleware adds security headers to all responses
func securityHeadersMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Prevent MIME type sniffing
		w.Header().Set("X-Content-Type-Options", "nosniff")

		// Prevent clickjacking
		w.Header().Set("X-Frame-Options", "DENY")

		// Basic CSP for API - only allow same-origin
		w.Header().Set("Content-Security-Policy", "default-src 'none'; frame-ancestors 'none'")

		// Prevent XSS in older browsers
		w.Header().Set("X-XSS-Protection", "1; mode=block")

		// Disable caching for API responses (security-sensitive data)
		w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, private")

		next.ServeHTTP(w, r)
	})
}

// corsMiddleware creates CORS middleware with the given configuration
func corsMiddleware(config CORSConfig) func(next http.Handler) http.Handler {
	return cors.Handler(cors.Options{
		AllowOriginFunc: func(r *http.Request, origin string) bool {
			// Allow configured production origins
			for _, allowed := range config.AllowedOrigins {
				if origin == allowed {
					return true
				}
			}
			// Allow localhost in development (any port)
			if config.AllowLocalhost && strings.HasPrefix(origin, "http://localhost:") {
				return true
			}
			return false
		},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type", "X-API-Key", "X-Request-ID"},
		ExposedHeaders:   []string{"X-Request-ID"},
		AllowCredentials: false,
		MaxAge:           300, // 5 minutes
	})
}

// isHealthEndpoint returns true if the path is a health check endpoint
func isHealthEndpoint(path string) bool {
	return path == "/health" || path == "/health/ready" || path == "/api/v1/health"
}

// isWriteMethod returns true if the method modifies data
func isWriteMethod(method string) bool {
	return method == "POST" || method == "PUT" || method == "DELETE" || method == "PATCH"
}

// isBackupEndpoint returns true if the path is a backup endpoint
func isBackupEndpoint(path string) bool {
	return strings.HasPrefix(path, "/api/v1/backup")
}

// conditionalRateLimitMiddleware applies different rate limits based on request type
func conditionalRateLimitMiddleware(config RateLimitConfig) func(next http.Handler) http.Handler {
	// Create rate limit handlers for each type with Retry-After header
	makeLimitHandler := func(window time.Duration) http.HandlerFunc {
		return func(w http.ResponseWriter, r *http.Request) {
			w.Header().Set("Content-Type", "application/json")
			w.Header().Set("Retry-After", fmt.Sprintf("%d", int(window.Seconds())))
			w.WriteHeader(http.StatusTooManyRequests)
			_, _ = w.Write([]byte(`{"error":"rate limit exceeded"}`))
		}
	}

	readLimitMiddleware := httprate.Limit(
		config.ReadLimit,
		config.Window,
		httprate.WithKeyFuncs(func(r *http.Request) (string, error) {
			return GetClientIP(r.Context()), nil
		}),
		httprate.WithLimitHandler(makeLimitHandler(config.Window)),
	)

	writeLimitMiddleware := httprate.Limit(
		config.WriteLimit,
		config.Window,
		httprate.WithKeyFuncs(func(r *http.Request) (string, error) {
			return GetClientIP(r.Context()), nil
		}),
		httprate.WithLimitHandler(makeLimitHandler(config.Window)),
	)

	backupLimitMiddleware := httprate.Limit(
		config.BackupLimit,
		config.BackupWindow,
		httprate.WithKeyFuncs(func(r *http.Request) (string, error) {
			return GetClientIP(r.Context()), nil
		}),
		httprate.WithLimitHandler(makeLimitHandler(config.BackupWindow)),
	)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			// Health endpoints are exempt from rate limiting
			if isHealthEndpoint(r.URL.Path) {
				next.ServeHTTP(w, r)
				return
			}

			// Select the appropriate rate limiter based on request type
			var limiterMiddleware func(http.Handler) http.Handler

			switch {
			case isBackupEndpoint(r.URL.Path):
				limiterMiddleware = backupLimitMiddleware
			case isWriteMethod(r.Method):
				limiterMiddleware = writeLimitMiddleware
			default:
				limiterMiddleware = readLimitMiddleware
			}

			// Apply the selected rate limiter
			limiterMiddleware(next).ServeHTTP(w, r)
		})
	}
}

// gzipMinSize is the minimum response size to trigger compression
const gzipMinSize = 1024 // 1KB

// gzipWriterPool reuses gzip writers to reduce allocations
var gzipWriterPool = sync.Pool{
	New: func() interface{} {
		return gzip.NewWriter(io.Discard)
	},
}

// gzipResponseWriter wraps http.ResponseWriter to compress responses.
// It delays sending headers until the compression decision is made.
type gzipResponseWriter struct {
	http.ResponseWriter
	gzipWriter  *gzip.Writer
	buffer      []byte
	compressed  bool
	statusCode  int  // Buffered status code
	wroteHeader bool // Whether we've sent headers to the underlying writer
}

func (grw *gzipResponseWriter) WriteHeader(code int) {
	// Buffer the status code but don't send it yet - we need to wait
	// until we know if we're compressing to set Content-Encoding
	if grw.statusCode == 0 {
		grw.statusCode = code
	}
}

func (grw *gzipResponseWriter) Write(b []byte) (int, error) {
	// Default to 200 if WriteHeader wasn't called
	if grw.statusCode == 0 {
		grw.statusCode = http.StatusOK
	}

	// If not yet decided on compression, buffer the data
	if !grw.compressed && len(grw.buffer) < gzipMinSize {
		grw.buffer = append(grw.buffer, b...)
		// If buffer exceeds threshold, start compression
		if len(grw.buffer) >= gzipMinSize {
			grw.startCompression()
		}
		return len(b), nil
	}

	if grw.compressed {
		return grw.gzipWriter.Write(b)
	}

	// Not compressing and already decided - write directly
	if !grw.wroteHeader {
		grw.ResponseWriter.WriteHeader(grw.statusCode)
		grw.wroteHeader = true
	}
	return grw.ResponseWriter.Write(b)
}

func (grw *gzipResponseWriter) startCompression() {
	grw.compressed = true
	grw.ResponseWriter.Header().Set("Content-Encoding", "gzip")
	grw.ResponseWriter.Header().Del("Content-Length") // Length changes with compression
	grw.ResponseWriter.WriteHeader(grw.statusCode)
	grw.wroteHeader = true
	grw.gzipWriter = gzipWriterPool.Get().(*gzip.Writer)
	grw.gzipWriter.Reset(grw.ResponseWriter)
}

func (grw *gzipResponseWriter) Close() error {
	// Write any buffered data
	if len(grw.buffer) > 0 {
		if grw.compressed {
			// Should have started compression already
			_, _ = grw.gzipWriter.Write(grw.buffer)
		} else {
			// Buffer didn't exceed threshold, write uncompressed
			if !grw.wroteHeader {
				if grw.statusCode == 0 {
					grw.statusCode = http.StatusOK
				}
				grw.ResponseWriter.WriteHeader(grw.statusCode)
				grw.wroteHeader = true
			}
			_, _ = grw.ResponseWriter.Write(grw.buffer)
		}
		grw.buffer = nil
	}

	// Handle case where WriteHeader was called but no body written
	if !grw.wroteHeader && grw.statusCode != 0 {
		grw.ResponseWriter.WriteHeader(grw.statusCode)
		grw.wroteHeader = true
	}

	if grw.compressed && grw.gzipWriter != nil {
		err := grw.gzipWriter.Close()
		gzipWriterPool.Put(grw.gzipWriter)
		return err
	}
	return nil
}

// gzipMiddleware compresses JSON responses above the minimum size threshold
func gzipMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Check if client accepts gzip
		if !strings.Contains(r.Header.Get("Accept-Encoding"), "gzip") {
			next.ServeHTTP(w, r)
			return
		}

		// Only compress JSON responses
		grw := &gzipResponseWriter{
			ResponseWriter: w,
			buffer:         make([]byte, 0, gzipMinSize),
		}

		next.ServeHTTP(grw, r)

		// Close the gzip writer to flush any remaining data
		_ = grw.Close()
	})
}

// SetupMiddleware applies the full middleware chain to the server's router
func (s *Server) SetupMiddleware(config MiddlewareConfig) {
	r := s.router

	// 1. Security headers - add to all responses
	r.Use(securityHeadersMiddleware)

	// 2. Body size limit - prevent memory exhaustion
	r.Use(bodySizeLimitMiddleware)

	// 3. RequestID - generate unique ID for tracing
	r.Use(middleware.RequestID)
	r.Use(requestIDMiddleware)

	// 4. RealIP - extract client IP from headers
	r.Use(realIPMiddleware)

	// 5. Logger - structured request/response logging
	r.Use(loggerMiddleware(config.Logger))

	// 6. Recoverer - panic recovery
	r.Use(recoverMiddleware(config.Logger))

	// 7. Timeout - request timeout
	r.Use(timeoutMiddleware(config.Timeout))

	// 8. RateLimit - per-IP rate limiting (health endpoints exempt)
	r.Use(conditionalRateLimitMiddleware(config.RateLimit))

	// 9. CORS - cross-origin support
	r.Use(corsMiddleware(config.CORS))

	// 10. Gzip compression - compress responses > 1KB for clients that accept it
	r.Use(gzipMiddleware)
}
