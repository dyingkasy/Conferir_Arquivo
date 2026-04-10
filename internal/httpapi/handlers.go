package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"
	"strings"
	"time"

	"conferir_arquivo/internal/auth"
	"conferir_arquivo/internal/model"
	"conferir_arquivo/internal/store"
)

type Handler struct {
	logger *slog.Logger
	store  *store.Postgres
}

func (h *Handler) Health(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	if err := h.store.Health(ctx); err != nil {
		writeJSON(w, http.StatusServiceUnavailable, map[string]any{
			"status":   "error",
			"database": "unavailable",
		})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"status":   "ok",
		"service":  "conferearquivo-api",
		"database": "ok",
	})
}

func (h *Handler) ConfigCheck(w http.ResponseWriter, r *http.Request) {
	var req model.ConfigCheckRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	token := auth.BearerToken(r.Header.Get("Authorization"))
	cnpj := model.NormalizeDigits(req.CNPJEmpresa)
	if cnpj == "" || token == "" || strings.TrimSpace(req.InstalacaoID) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cnpj_empresa, instalacao_id and bearer token are required"})
		return
	}

	if _, err := h.store.EnsureTenantToken(r.Context(), cnpj, token, req.RazaoSocial); err != nil {
		h.logger.Error("failed to provision tenant during config-check", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to provision tenant"})
		return
	}

	if err := h.store.SaveHeartbeat(r.Context(), cnpj, req.InstalacaoID, remoteIP(r)); err != nil {
		h.logger.Error("failed to save heartbeat during config-check", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to persist heartbeat"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":   "ok",
		"mensagem": "Configuracao validada.",
	})
}

func (h *Handler) Heartbeat(w http.ResponseWriter, r *http.Request) {
	var req model.HeartbeatRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	token := auth.BearerToken(r.Header.Get("Authorization"))
	cnpj := model.NormalizeDigits(req.CNPJEmpresa)
	if cnpj == "" || token == "" || strings.TrimSpace(req.InstalacaoID) == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cnpj_empresa, instalacao_id and bearer token are required"})
		return
	}

	if _, err := h.store.EnsureTenantToken(r.Context(), cnpj, token, ""); err != nil {
		h.logger.Error("failed to provision tenant during heartbeat", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to provision tenant"})
		return
	}

	if err := h.store.SaveHeartbeat(r.Context(), cnpj, req.InstalacaoID, remoteIP(r)); err != nil {
		h.logger.Error("failed to save heartbeat", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to persist heartbeat"})
		return
	}

	writeJSON(w, http.StatusOK, map[string]string{
		"status":   "ok",
		"mensagem": "Heartbeat recebido.",
	})
}

func (h *Handler) Lote(w http.ResponseWriter, r *http.Request) {
	var req model.LoteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	token := auth.BearerToken(r.Header.Get("Authorization"))
	if model.NormalizeDigits(req.CNPJEmpresa) == "" || token == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cnpj_empresa and bearer token are required"})
		return
	}

	if err := h.store.SaveLote(r.Context(), req, token, remoteIP(r)); err != nil {
		if errors.Is(err, store.ErrUnauthorized) {
			h.writeAuthError(w, err)
			return
		}

		h.logger.Error("failed to persist lote", "error", err)
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"status":     "ok",
		"mensagem":   "Lote recebido e persistido.",
		"quantidade": req.Quantidade,
	})
}

func (h *Handler) Empresas(w http.ResponseWriter, r *http.Request) {
	token := auth.BearerToken(r.Header.Get("Authorization"))
	if token == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "bearer token is required"})
		return
	}
	items, err := h.store.ListEmpresas(r.Context(), token)
	if err != nil {
		h.logger.Error("failed to list empresas", "error", err)
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "failed to list empresas"})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":     "ok",
		"quantidade": len(items),
		"items":      items,
	})
}

func (h *Handler) Resumo(w http.ResponseWriter, r *http.Request) {
	token := auth.BearerToken(r.Header.Get("Authorization"))
	cnpj := model.NormalizeDigits(r.URL.Query().Get("cnpj_empresa"))
	dias := 7
	if value := strings.TrimSpace(r.URL.Query().Get("dias")); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			dias = parsed
		}
	}
	if cnpj == "" || token == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cnpj_empresa and bearer token are required"})
		return
	}
	resp, err := h.store.GetResumo(r.Context(), cnpj, token, dias)
	if err != nil {
		h.writeAuthError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) Lista(w http.ResponseWriter, r *http.Request) {
	token := auth.BearerToken(r.Header.Get("Authorization"))
	cnpj := model.NormalizeDigits(r.URL.Query().Get("cnpj_empresa"))
	status := strings.TrimSpace(r.URL.Query().Get("status_operacional"))
	dataInicial := strings.TrimSpace(r.URL.Query().Get("data_inicial"))
	dataFinal := strings.TrimSpace(r.URL.Query().Get("data_final"))
	limit := 200
	if value := strings.TrimSpace(r.URL.Query().Get("limit")); value != "" {
		if parsed, err := strconv.Atoi(value); err == nil {
			limit = parsed
		}
	}
	if cnpj == "" || token == "" {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "cnpj_empresa and bearer token are required"})
		return
	}
	items, err := h.store.ListNFCe(r.Context(), cnpj, token, status, dataInicial, dataFinal, limit)
	if err != nil {
		h.writeAuthError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"status":     "ok",
		"quantidade": len(items),
		"items":      items,
	})
}

func (h *Handler) writeAuthError(w http.ResponseWriter, err error) {
	if errors.Is(err, store.ErrUnauthorized) {
		writeJSON(w, http.StatusUnauthorized, map[string]string{
			"status":   "unauthorized",
			"mensagem": "Token invalido para a empresa",
		})
		return
	}

	h.logger.Error("tenant validation failed", "error", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "tenant validation failed"})
}

func decodeJSON(r *http.Request, dst any) error {
	defer r.Body.Close()
	decoder := json.NewDecoder(r.Body)
	if err := decoder.Decode(dst); err != nil {
		return err
	}
	return nil
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func remoteIP(r *http.Request) string {
	if forwarded := strings.TrimSpace(r.Header.Get("X-Forwarded-For")); forwarded != "" {
		parts := strings.Split(forwarded, ",")
		return strings.TrimSpace(parts[0])
	}
	if realIP := strings.TrimSpace(r.Header.Get("X-Real-IP")); realIP != "" {
		return realIP
	}
	return r.RemoteAddr
}
