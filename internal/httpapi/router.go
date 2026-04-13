package httpapi

import (
	"log/slog"
	"net/http"
	"time"

	"conferir_arquivo/internal/store"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
)

func NewRouter(logger *slog.Logger, pgStore *store.Postgres) http.Handler {
	handler := &Handler{
		logger: logger,
		store:  pgStore,
	}

	r := chi.NewRouter()
	r.Use(middleware.RealIP)
	r.Use(middleware.RequestID)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Timeout(60 * time.Second))
	r.Use(requestLogger(logger))

	r.Get("/health", handler.Health)
	r.Get("/api/v1/empresas", handler.Empresas)
	r.Post("/api/v1/agente/config-check", handler.ConfigCheck)
	r.Post("/api/v1/agente/heartbeat", handler.Heartbeat)
	r.Post("/api/v1/nfce/lote", handler.Lote)
	r.Post("/api/v1/nfe-saida/lote", handler.NFeSaidaLote)
	r.Get("/api/v1/nfce/resumo", handler.Resumo)
	r.Get("/api/v1/nfce/lista", handler.Lista)
	r.Get("/api/v1/nfce/series", handler.Series)
	r.Get("/api/v1/nfce/computadores", handler.Computadores)
	r.Get("/api/v1/nfe-saida/resumo", handler.NFeSaidaResumo)
	r.Get("/api/v1/nfe-saida/lista", handler.NFeSaidaLista)
	r.Get("/api/v1/nfe-saida/series", handler.NFeSaidaSeries)
	r.Get("/api/v1/nfe-saida/computadores", handler.NFeSaidaComputadores)

	return r
}

func requestLogger(logger *slog.Logger) func(http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			start := time.Now()
			ww := middleware.NewWrapResponseWriter(w, r.ProtoMajor)
			next.ServeHTTP(ww, r)
			logger.Info("http request",
				"method", r.Method,
				"path", r.URL.Path,
				"status", ww.Status(),
				"bytes", ww.BytesWritten(),
				"duration_ms", time.Since(start).Milliseconds(),
				"remote_ip", r.RemoteAddr,
				"request_id", middleware.GetReqID(r.Context()),
			)
		})
	}
}
