package main

import (
	"context"
	"log"
	"net/http"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"

	rpcv1 "github.com/33TU/as3pb/runtime/test/rpc-server/gen"
	"github.com/33TU/as3pb/runtime/test/rpc-server/gen/genconnect"
	"google.golang.org/protobuf/encoding/protojson"
)

type rpcFixtureServer struct{}

func (rpcFixtureServer) Echo(ctx context.Context, req *rpcv1.RpcEchoRequest) (*rpcv1.RpcEchoResponse, error) {
	reqJSON, _ := protojson.MarshalOptions{Indent: "  "}.Marshal(req)
	log.Printf("Echo request:\n%s", reqJSON)

	return &rpcv1.RpcEchoResponse{
		Message: req.GetMessage(),
		Ok:      true,
	}, nil
}

func main() {
	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Logger)
	r.Use(cors)
	r.Use(logRequests)

	path, handler := genconnect.NewRpcFixtureServiceHandler(rpcFixtureServer{})
	r.Mount(path, handler)
	r.Get("/crossdomain.xml", crossdomainXML)
	r.NotFound(func(w http.ResponseWriter, r *http.Request) {
		http.NotFound(w, r)
	})

	server := &http.Server{
		Addr:              "localhost:8080",
		Handler:           r,
		ReadHeaderTimeout: 5 * time.Second,
	}

	log.Println("AS3PB RPC test server listening on http://localhost:8080")
	log.Println("RPC endpoint: http://localhost:8080/rpc.RpcFixtureService/Echo")
	if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}

func cors(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Connect-Protocol-Version, Connect-Timeout-Ms")
		w.Header().Set("Access-Control-Max-Age", "86400")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}

func logRequests(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s content-type=%q length=%d", r.Method, r.URL.Path, r.Header.Get("Content-Type"), r.ContentLength)
		next.ServeHTTP(w, r)
	})
}

func crossdomainXML(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "text/x-cross-domain-policy")
	_, _ = w.Write([]byte(`<?xml version="1.0"?>
<!DOCTYPE cross-domain-policy SYSTEM "http://www.adobe.com/xml/dtds/cross-domain-policy.dtd">
<cross-domain-policy>
  <allow-access-from domain="*" />
  <allow-http-request-headers-from domain="*" headers="*" />
</cross-domain-policy>
`))
}
