package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

// Config holds server configuration from environment variables.
type Config struct {
	Port       string
	StaticDir  string
	AnswerDir  string
}

func configFromEnv() Config {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	staticDir := os.Getenv("STATIC_DIR")
	if staticDir == "" {
		staticDir = "/srv"
	}
	answerDir := os.Getenv("ANSWER_DIR")
	if answerDir == "" {
		answerDir = "/answers"
	}
	return Config{Port: port, StaticDir: staticDir, AnswerDir: answerDir}
}

// SystemInfo is the JSON payload the Proxmox installer POSTs to /answer.
type SystemInfo struct {
	NetworkInterface struct {
		MAC string `json:"mac"`
	} `json:"network-interface"`
}

func main() {
	cfg := configFromEnv()

	mux := http.NewServeMux()

	// POST /answer — serve per-MAC or default answer file
	mux.HandleFunc("POST /answer", answerHandler(cfg))

	// GET /* — static file server
	mux.Handle("GET /", http.FileServer(http.Dir(cfg.StaticDir)))

	addr := ":" + cfg.Port
	log.Printf("PXE HTTP server listening on %s", addr)
	log.Printf("  Static files: %s", cfg.StaticDir)
	log.Printf("  Answer files: %s", cfg.AnswerDir)

	if err := http.ListenAndServe(addr, mux); err != nil {
		log.Fatalf("Server failed: %v", err)
	}
}

func answerHandler(cfg Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			http.Error(w, "failed to read request body", http.StatusInternalServerError)
			return
		}
		defer r.Body.Close()

		answerFile := filepath.Join(cfg.AnswerDir, "default.toml")

		// Try to find a per-MAC answer file
		var info SystemInfo
		if err := json.Unmarshal(body, &info); err == nil {
			mac := strings.ReplaceAll(info.NetworkInterface.MAC, ":", "")
			mac = strings.ToLower(mac)
			if mac != "" {
				perNode := filepath.Join(cfg.AnswerDir, mac+".toml")
				if _, err := os.Stat(perNode); err == nil {
					answerFile = perNode
					log.Printf("Serving per-node answer file: %s", perNode)
				}
			}
		}

		content, err := os.ReadFile(answerFile)
		if err != nil {
			log.Printf("Answer file not found: %s", answerFile)
			http.Error(w, "answer file not found", http.StatusNotFound)
			return
		}

		w.Header().Set("Content-Type", "text/plain")
		w.Header().Set("Content-Length", fmt.Sprintf("%d", len(content)))
		w.WriteHeader(http.StatusOK)
		w.Write(content)

		log.Printf("Served %s (%d bytes)", answerFile, len(content))
	}
}
