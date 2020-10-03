package main

import (
	"bufio"
	"fmt"
	"net/http"
	"os"
	"sync"
)

type sourceChan = chan string

// Constants
const (
	inputBufferSize = 100
	workersNumber = 200
)

func makeSource() (source sourceChan) {
	source = make(sourceChan, inputBufferSize)
	go func() {
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			source <- scanner.Text()
		}
		close(source)
	}()
	return source
}

func isURLExists(url string) bool {
	// fmt.Printf("%#v\n", url)
	res, err := http.Head(url)
	if err != nil || res.StatusCode >= 400 {
		return false
	}
	// fmt.Printf("%#v\n", res)
	return true
}

func makeWorker(source sourceChan, wg *sync.WaitGroup) {
	wg.Add(1)
	go func() {
		for url := range source {
			if isURLExists(url) {
				fmt.Fprintln(os.Stdout, url)
			} else {
				fmt.Fprintln(os.Stderr, url)
			}
		}
		wg.Done()
	}()
}

func main() {
	source := makeSource()
	wg := sync.WaitGroup{}
	for i := 1; i <= workersNumber; i++ {
		makeWorker(source, &wg)
	}
	wg.Wait()
}
