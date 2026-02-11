package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/rpc"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"syscall"

	"github.com/BurntSushi/toml"
	"github.com/bwmarrin/discordgo"
	"github.com/fsnotify/fsnotify"
)

func init() {
	flag.StringVar(&configFile, "c", "", "Config file")
	flag.BoolVar(&daemon, "d", false, "Run in daemon mode")
	flag.Parse()
}

var (
	configFile      string
	gitCommit       string
	config          Config
	daemon          bool
	dg              *discordgo.Session
	processingFiles sync.Map
	echoRegex              = regexp.MustCompile("^`([^`]+)`")
	separator       string = "|"
)

func main() {
	var err error
	log.Printf("Starting logger")
	if configFile == "" {
		configFile = "config.toml"
	}
	if _, err = toml.DecodeFile(configFile, &config); err != nil {
		log.Fatal(err)
	}
	log.Printf("Config loaded")

	if daemon {
		os.Exit(runDaemon())
	}

	client, err := rpc.DialHTTP("tcp", fmt.Sprintf("127.0.0.1:%s", config.LoopbackPort))
	if err != nil {
		log.Fatal(err)
	}
	args := os.Args
	if len(args) < 3 {
		log.Fatal("Not enough arguments")
	}
	cmsin := new(CMSInput)
	cmsin.User = args[3]
	cmsin.Node = args[4]
	cmsin.Command = args[5]
	cmsin.Message = strings.Join(args[6:], " ")

	err = client.Call("CMSInput.Dispatch", cmsin, nil)
	if err != nil {
		log.Fatal(err)
	}
	client.Close()

}

func runDaemon() int {
	var err error
	dg, err = discordgo.New("Bot " + config.Token)
	if err != nil {
		log.Println(err)
		return -1
	}

	err = dg.Open()
	if err != nil {
		log.Println(err)
		return -1
	}
	defer dg.Close()

	dg.Identify.Intents = discordgo.MakeIntent(discordgo.IntentsAll)
	dg.AddHandler(ready)

	cmsin := new(CMSInput)
	rpc.Register(cmsin)
	rpc.HandleHTTP()

	l, e := net.Listen("tcp", fmt.Sprintf("127.0.0.1:%s", config.LoopbackPort))
	if e != nil {
		log.Fatal("listen error:", e)
	}
	go http.Serve(l, nil)
	go startSpoolMonitor()
	sc := make(chan os.Signal, 1)
	signal.Notify(sc, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-sc
	dg.Close()
	return 0
}

func ready(s *discordgo.Session, event *discordgo.Ready) {
	s.UpdateGameStatus(0, fmt.Sprintf("DiscordCMS rev %+v", gitCommit))
}

func startSpoolMonitor() {
	if config.SpoolDirectory == "" {
		log.Println("Spool monitor disabled (no directory configured)")
		return
	}

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Printf("Failed to create file watcher: %v", err)
		return
	}
	defer watcher.Close()

	err = watcher.Add(config.SpoolDirectory)
	if err != nil {
		log.Printf("Failed to watch spool directory %s: %v", config.SpoolDirectory, err)
		return
	}

	log.Printf("Starting spool monitor on %s (using fsnotify)", config.SpoolDirectory)

	// Process any existing files on startup
	scanSpool()

	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			// React to new or modified files
			if event.Op&(fsnotify.Create|fsnotify.Write) != 0 {
				scanSpool()
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Printf("Spool watcher error: %v", err)
		}
	}
}

func scanSpool() {
	files, err := os.ReadDir(config.SpoolDirectory)
	if err != nil {
		log.Printf("Error reading spool directory: %v", err)
		return
	}

	for _, file := range files {
		if !file.IsDir() && !strings.HasPrefix(file.Name(), ".") {
			fullPath := filepath.Join(config.SpoolDirectory, file.Name())

			if _, loaded := processingFiles.LoadOrStore(fullPath, true); loaded {
				continue
			}

			go func(path string) {
				defer processingFiles.Delete(path)
				processSpoolFile(path)
			}(file.Name())
		}
	}
}

func processSpoolFile(path string) {
	log.Printf("Processing spool file: %s", path)
	tempFile := filepath.Join("/tmp", filepath.Base(path)+".txt")

	defer os.Remove(tempFile)
	cmd := exec.Command("sudo", "-u", strings.ToLower(config.BotUser), config.NJEReceivePath, "-o", tempFile, path)
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("Failed to execute receive for %s: %v. Output: %s", path, err, string(out))
		return
	}

	content, err := os.ReadFile(tempFile)
	if err != nil {
		log.Printf("Failed to read converted temp file %s: %v", tempFile, err)
		return
	}
	var rUser, rNode string
	words := strings.Fields(string(content))
	if len(words) >= 6 &&
		strings.EqualFold(words[2], "from") &&
		strings.EqualFold(words[4], "at") {

		rUser = words[3]
		rNode = words[5]
	}

	go Announce(&CMSInput{
		User:    rUser,
		Node:    rNode,
		Message: fmt.Sprintf("```%s```", string(content)),
	})
}
