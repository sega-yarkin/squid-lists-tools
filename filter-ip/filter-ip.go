package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
)

func isIPAddr(s string) bool {
	addr := net.ParseIP(s)
	return addr != nil
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	for scanner.Scan() {
		host := scanner.Text()
		if isIPAddr(host) {
			fmt.Fprintln(os.Stderr, host)
		} else {
			fmt.Fprintln(os.Stdout, host)
		}
	}
	if err := scanner.Err(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}
