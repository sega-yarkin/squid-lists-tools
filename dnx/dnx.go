package main

import (
	"fmt"
	"log"
	"os"
	"bufio"
	"sync"
	"sync/atomic"
	"time"
	"errors"
	"net"

	dns "github.com/miekg/dns"
)

const (
	logFd uintptr = 3
	inputBufferSize = 100
	backlogBufferSize = 100
	workersNumber = 200
	dialTimeout = 10 * time.Second
	dialNetwork = "tcp"
	requestTimeout = 10 * time.Second
	connIdleTimeout = 10 * time.Second
)

var resolversList = []string {
	"8.8.8.8:53",
	"8.8.8.8:53",
	"8.8.4.4:53",
	"1.1.1.1:53",
	"1.1.1.1:53",
	"1.0.0.1:53",
	"208.67.222.222:53",
	"208.67.220.220:53",
	"185.121.177.177:53",
	"128.31.0.72:53",
	"172.98.193.42:53",
	"162.248.241.94:53",
	// "50.116.17.96:53",
	"66.187.76.168:53",
	// "147.135.76.183:53",
}

func makeSource(inflight *int64) (source chan string) {
	source = make(chan string, inputBufferSize)
	go func() {
		log.Println("Reading from stdin")
		count := 0
		scanner := bufio.NewScanner(os.Stdin)
		for scanner.Scan() {
			atomic.AddInt64(inflight, 1)
			source <- scanner.Text()
			count += 1
			if (count % 10000) == 0 {
				log.Printf("%d", count)
			}
		}
		close(source)
		log.Println("Source finished")
	}()
	return source
}


type Worker struct {
	wg        *sync.WaitGroup
	source    chan string
	backlog   chan string
	inflight  *int64
	dnsServer string
	conn      *dns.Conn
}

func StartWorker(wg *sync.WaitGroup, source, backlog chan string, inflight *int64, dnsServer string) {
	wrk := &Worker{wg, source, backlog, inflight, dnsServer, nil}
	wg.Add(1)
	go wrk.lifecycle()
}

func (wrk *Worker) log(level, format string, v ...interface{}) {
	v = append([]interface{}{level, wrk.dnsServer}, v...)
	log.Printf("%s[%s]: " + format, v...)
}

func (wrk *Worker) lifecycle() {
	var err error
	var fqdn string
	var resp *dns.Msg
	var ok bool
	finished := false
	total := 0
	for !finished {
		err = wrk.createConnection()
		count := 0
		if err != nil {
			wrk.log("E", "Cannot connect: %#v", err)
			time.Sleep(1 * time.Second)
			continue
		}
		// wrk.log("I", "Connected")
		var latestFinishTime time.Time

		for !wrk.isFinished() {
			latestFinishTime = time.Now()
			select {
			case fqdn, ok = <-wrk.backlog:
				if !ok {
					wrk.backlog = nil
					continue
				}
			case fqdn, ok = <-wrk.source:
				if !ok {
					wrk.source = nil
					wrk.maybeCloseBacklog()
					continue
				}
			}
			// wrk.log("I", "Resolving %s", fqdn)
			count += 1
			total += 1
			resp, err = wrk.makeRequest(fqdn)
			if err == nil {
				log.Writer().Write([]byte{'.'})
				wrk.markProcessed()
				if resp.Answer != nil {
					// wrk.log("I", "%#v", resp.Answer[0])
					fmt.Fprintln(os.Stdout, fqdn)
				} else {
					fmt.Fprintln(os.Stderr, fqdn)
				}
				wrk.maybeCloseBacklog()
			} else {
				log.Writer().Write([]byte{'!'})
				if wrk.isDataError(err) {
					wrk.markProcessed()
					continue
				}
				timeDiff := time.Since(latestFinishTime)
				if wrk.shouldLogError(err, timeDiff) {
					wrk.log("E", "Error while resolving %s (#%d, %v): %#v", fqdn, count, timeDiff, err)
				}
				wrk.backlog <- fqdn
				break
			}
		}
		finished = err == nil
	}

	if wrk.conn != nil {
		// wrk.log("I", "Closing connection")
		wrk.conn.Close()
	}
	wrk.wg.Done()
}

func (wrk *Worker) createConnection() (err error) {
	log.Writer().Write([]byte{'#'})
	if wrk.conn != nil {
		wrk.conn.Close()
	}
	wrk.conn, err = dns.DialTimeout(dialNetwork, wrk.dnsServer, dialTimeout)
	return
}

func (wrk *Worker) makeRequest(fqdn string) (resp *dns.Msg, err error) {
	// Prepare
	req := new(dns.Msg)
	req.SetQuestion(dns.Fqdn(fqdn), dns.TypeA)
	// Send
	wrk.conn.SetWriteDeadline(time.Now().Add(requestTimeout))
	if err = wrk.conn.WriteMsg(req); err != nil {
		return
	}
	// Receive
	wrk.conn.SetReadDeadline(time.Now().Add(requestTimeout))
	resp, err = wrk.conn.ReadMsg()
	if err == nil && resp.Id != req.Id {
		err = errors.New("id mismatch")
	}
	return
}

func (wrk *Worker) isFinished() bool {
	return wrk.source == nil && wrk.backlog == nil //&& atomic.LoadInt64(wrk.inflight) < 1
}

func (wrk *Worker) markProcessed() {
	atomic.AddInt64(wrk.inflight, -1)
}

func (wrk *Worker) maybeCloseBacklog() {
	if wrk.backlog != nil && wrk.source == nil && atomic.LoadInt64(wrk.inflight) < 1 {
		close(wrk.backlog)
	}
}

func (*Worker) isDataError(err error) bool {
	// Wrong DNS name
	if err == dns.ErrRdata {
		return true
	}
	return false
}

func (*Worker) shouldLogError(err error, dur time.Duration) bool {
	if err.Error() == "EOF" {
		return false
	}
	if nerr, ok := err.(*net.OpError); ok {
		if nerr.Timeout() || nerr.Temporary() {
			return false
		}
		if nerr.Op == "writev" && dur > connIdleTimeout {
			return false
		}
	}
	return true
}


func main() {
	log.SetOutput(os.NewFile(logFd, "logging"))
	inflight := int64(0)
	source := makeSource(&inflight)
	backlog := make(chan string, backlogBufferSize)
	wg := sync.WaitGroup{}

	for i := 0; i < workersNumber; i++ {
		resolver := resolversList[i % len(resolversList)]
		StartWorker(&wg, source, backlog, &inflight, resolver)
	}
	wg.Wait()
}
