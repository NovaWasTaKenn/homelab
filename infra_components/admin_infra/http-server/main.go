package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"text/template"
)

type Config struct {
	Port         string
	StaticDir    string
	AnswerDir    string
	RootPassword string
	NodePrefix   string
	StateFile    string
	RegistryFile string
	AdminHost    string
}

func configFromEnv() Config {
	get := func(key, def string) string {
		if v := os.Getenv(key); v != "" {
			return v
		}
		return def
	}

	return Config{
		Port:         get("PORT", "8080"),
		StaticDir:    get("STATIC_DIR", "/srv"),
		AnswerDir:    get("ANSWER_DIR", "/answers"),
		RootPassword: get("ROOT_PASSWORD", ""),
		NodePrefix:   get("NODE_PREFIX", "node"),
		StateFile:    get("STATE_FILE", "/data/nodes.json"),
		RegistryFile: get("REGISTRY_FILE", "/registry/nodes.json"),
		AdminHost:    get("ADMIN_HOST", ""),
	}
}

// NodeState persists MAC → node ID mappings across restarts.
type NodeState struct {
	Nodes   map[string]int `json:"nodes"`   // mac → id
	Counter int            `json:"counter"` // next id to assign
}

func loadState(path string) (*NodeState, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return &NodeState{Nodes: make(map[string]int), Counter: 0}, nil
	}
	if err != nil {
		return nil, err
	}
	var s NodeState
	if err := json.Unmarshal(data, &s); err != nil {
		return nil, err
	}
	return &s, nil
}

func (s *NodeState) save(path string) error {
	data, err := json.MarshalIndent(s, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

// NodeRegistry is the shared node name → IP mapping written by this server
// and consumed by Terraform and Ansible.
type NodeRegistry struct {
	Nodes map[string]string `json:"nodes"` // name → ip
}

func loadRegistry(path string) (*NodeRegistry, error) {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return &NodeRegistry{Nodes: make(map[string]string)}, nil
	}
	if err != nil {
		return nil, err
	}
	var r NodeRegistry
	if err := json.Unmarshal(data, &r); err != nil {
		return nil, err
	}
	if r.Nodes == nil {
		r.Nodes = make(map[string]string)
	}
	return &r, nil
}

func (r *NodeRegistry) save(path string) error {
	data, err := json.MarshalIndent(r, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, data, 0644)
}

// resolveID returns the existing ID for a MAC, or assigns a new one.
func (s *NodeState) resolveID(mac string) (int, bool) {
	if id, exists := s.Nodes[mac]; exists {
		return id, false // existing node
	}
	s.Counter++
	s.Nodes[mac] = s.Counter
	return s.Counter, true // new node
}

type TemplateData struct {
	ROOT_PASSWORD string
	FQDN         string
	ADMIN_HOST    string
}

type NetworkInterface struct {
	Link string `json:"link"`
	MAC  string `json:"mac"`
}

type SystemInfo struct {
	NetworkInterfaces []NetworkInterface `json:"network_interfaces"`
}

type Server struct {
	cfg      Config
	mu       sync.Mutex
	state    *NodeState
	registry *NodeRegistry
}

func main() {
	cfg := configFromEnv()
	if cfg.RootPassword == "" {
		log.Fatal("ROOT_PASSWORD env var is required")
	}

	if err := os.MkdirAll(filepath.Dir(cfg.StateFile), 0755); err != nil {
		log.Fatalf("failed to create data directory: %v", err)
	}

	state, err := loadState(cfg.StateFile)
	if err != nil {
		log.Fatalf("failed to load state: %v", err)
	}

	if err := os.MkdirAll(filepath.Dir(cfg.RegistryFile), 0755); err != nil {
		log.Fatalf("failed to create registry directory: %v", err)
	}

	registry, err := loadRegistry(cfg.RegistryFile)
	if err != nil {
		log.Fatalf("failed to load node registry: %v", err)
	}

	s := &Server{cfg: cfg, state: state, registry: registry}

	mux := http.NewServeMux()
	mux.HandleFunc("POST /answer", s.answerHandler)
	mux.Handle("GET /", http.FileServer(http.Dir(cfg.StaticDir)))

	log.Printf("PXE HTTP server listening on :%s", cfg.Port)
	log.Fatal(http.ListenAndServe(":"+cfg.Port, mux))
}

func (s *Server) answerHandler(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "failed to read body", http.StatusInternalServerError)
		return
	}
	defer r.Body.Close()

	log.Printf("Request body: %s", body)

	mac := parseMac(body)

	if mac == "" {
		log.Print("Mac address is empty")
		http.Error(w, "Mac address is empty", http.StatusInternalServerError)
		return
	}

	// Resolve the node's identity and record its IP in the shared registry.
	s.mu.Lock()
	id, isNew := s.state.resolveID(mac)
	if isNew {
		if err := s.state.save(s.cfg.StateFile); err != nil {
			s.mu.Unlock()
			log.Printf("Failed to save state: %v", err)
			http.Error(w, "failed to save state", http.StatusInternalServerError)
			return
		}
	}
	name := fmt.Sprintf("%s-%d", s.cfg.NodePrefix, id)
	if ip := clientIP(r); s.registry.Nodes[name] != ip {
		s.registry.Nodes[name] = ip
		if err := s.registry.save(s.cfg.RegistryFile); err != nil {
			s.mu.Unlock()
			log.Printf("Failed to save node registry: %v", err)
			http.Error(w, "failed to save node registry", http.StatusInternalServerError)
			return
		}
	}
	s.mu.Unlock()

	action := "existing"
	if isNew {
		action = "new"
	}
	log.Printf("Answering %s node %s (%s, id=%d)", action, mac, name, id)

	// Per-MAC override takes priority
	if content, err := os.ReadFile(filepath.Join(s.cfg.AnswerDir, mac+".toml")); err == nil {
		log.Printf("Serving per-MAC override for %s", mac)
		w.Header().Set("Content-Type", "text/plain")
		w.Write(content)
		return
	}

	content, err := s.generateAnswer(name)
	if err != nil {
		log.Printf("Failed to generate answer: %v", err)
		http.Error(w, "failed to generate answer", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain")
	w.Write(content)
}

func (s *Server) generateAnswer(name string) ([]byte, error) {
	tmplContent, err := os.ReadFile(filepath.Join(s.cfg.AnswerDir, "template.toml"))
	if err != nil {
		return nil, fmt.Errorf("reading template: %w", err)
	}
	tmpl, err := template.New("answer").Parse(string(tmplContent))
	if err != nil {
		return nil, fmt.Errorf("parsing template: %w", err)
	}

	data := TemplateData{
		ROOT_PASSWORD: s.cfg.RootPassword,
		FQDN:         fmt.Sprintf("%s.pve.local", name),
		ADMIN_HOST:   s.cfg.AdminHost,
	}

	var buf strings.Builder
	if err := tmpl.Execute(&buf, data); err != nil {
		return nil, fmt.Errorf("executing template: %w", err)
	}
	return []byte(buf.String()), nil
}

// clientIP returns the request's source IP with the port stripped.
func clientIP(r *http.Request) string {
	ip, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return ip
}

// parseMac extracts the MAC of the first non-loopback wired interface.
// Falls back to the first interface if none match.
func parseMac(body []byte) string {
	var info SystemInfo
	if err := json.Unmarshal(body, &info); err != nil || len(info.NetworkInterfaces) == 0 {
		return ""
	}
	log.Printf("Parsed body: %s", info)
	// Prefer the first wired (non-wifi) interface
	for _, iface := range info.NetworkInterfaces {
		if !strings.HasPrefix(iface.Link, "wl") {
			return strings.ReplaceAll(strings.ToLower(iface.MAC), ":", "")
		}
	}
	// Fall back to first interface
	return strings.ReplaceAll(strings.ToLower(info.NetworkInterfaces[0].MAC), ":", "")
}
