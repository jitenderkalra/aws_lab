package main

import (
	"fmt"
	"log"
	"net/http"
)

const message = "Hello from DevOps stack!"

func handler(w http.ResponseWriter, r *http.Request) {
	_, _ = fmt.Fprintln(w, message)
}

func main() {
	http.HandleFunc("/", handler)
	log.Printf("Listening on :8081")
	log.Fatal(http.ListenAndServe(":8081", nil))
}
