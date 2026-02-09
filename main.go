package main

import (
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/rpc"
	"os"
	"os/signal"
	"regexp"
	"strings"
	"syscall"

	"github.com/BurntSushi/toml"
	"github.com/bwmarrin/discordgo"
)

func init() {
	flag.StringVar(&configFile, "c", "", "Config file")
	flag.BoolVar(&daemon, "d", false, "Run in daemon mode")
	flag.Parse()
}

var (
	configFile string
	gitCommit  string
	config     Config
	daemon     bool
	dg         *discordgo.Session
	echoRegex         = regexp.MustCompile("^`([^`]+)`")
	separator  string = "|"
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

	sc := make(chan os.Signal, 1)
	signal.Notify(sc, syscall.SIGINT, syscall.SIGTERM, os.Interrupt)
	<-sc
	dg.Close()
	return 0
}

func ready(s *discordgo.Session, event *discordgo.Ready) {
	s.UpdateGameStatus(0, fmt.Sprintf("DiscordCMS rev %+v", gitCommit))
}
