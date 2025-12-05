package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHandlerReturnsMessage(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()

	handler(w, req)

	if got := w.Body.String(); got != message+"\n" {
		t.Fatalf("expected %q, got %q", message+"\n", got)
	}
}
