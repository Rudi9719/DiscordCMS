package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"time"

	"github.com/bwmarrin/discordgo"
	"github.com/forPelevin/gomoji"
)

func (i *CMSInput) Dispatch(args *CMSInput, reply *string) error {
	log.Printf("Dispatching %s for %s(%s)", args.Command, args.Node, args.User)
	switch strings.ToLower(args.Command) {
	case "s":
		go Say(args)
	case "say":
		go Say(args)
	case "li":
		go List(args)
	case "list":
		go List(args)
	case "hist":
		go History(args)
	case "history":
		go History(args)
	case "a":
		go Announce(args)
	default:
		go i.notifyUser(fmt.Sprintf("Unknown command %s", args.Command))
		return fmt.Errorf("Unknown command %s from %s(%s)", args.Command, args.Node, args.User)
	}
	return nil
}

func Say(i *CMSInput) {
	parts := strings.Split(i.Message, " ")
	dg.ChannelMessageSend(parts[0], fmt.Sprintf("`%s(%s)` %s", i.Node, i.User, strings.Join(parts[1:], " ")))
}

func Announce(i *CMSInput) {
	if i.User != config.CMSUser || i.Node != config.CMSNode {
		go i.notifyUser("You are not permitted to use announce.")
		log.Printf("Invalid attempt to use Announce by %s(%s)", i.Node, i.User)
		return
	}
	dg.ChannelMessageSend(config.AnnounceChan, i.Message)
}

func List(i *CMSInput) {
	log.Println("Listing channels for", i.User, "at", i.Node)
	chanlist, err := dg.GuildChannels(config.DiscordGuild)
	if err != nil {
		go i.notifyUser("Discord failed to respond to list command.")
		log.Printf("%s(%s) failed List command [discord error]: %+v", i.Node, i.User, err)
		return
	}
	f, err := os.CreateTemp("/tmp", fmt.Sprintf("%s_%s_%s_.*", i.Node, i.User, "chanlist"))
	if err != nil {
		go i.notifyUser("Failed to prepare discord list.")
		log.Printf("%s(%s) failed List command [file error]: %+v", i.Node, i.User, err)
		return
	}
	w := bufio.NewWriter(f)
	_, err = fmt.Fprintf(w, "%s%s%d%s%s\n", "LIST", separator, len(chanlist), separator, time.Now().Format("01/02 15:04"))
	if err != nil {
		go i.notifyUser("Failed to write discord list.")
		log.Printf("%s(%s) failed List command [header writer error]: %+v", i.Node, i.User, err)
		return
	}
	for _, dchan := range chanlist {
		if dchan.Type != discordgo.ChannelTypeGuildText {
			continue
		}

		cleanTopic := strings.ReplaceAll(dchan.Topic, "\n", "")
		cleanTopic = strings.ReplaceAll(cleanTopic, "\r", "")
		cleanTopic = strings.ReplaceAll(cleanTopic, "  ", " ")

		_, err := fmt.Fprintf(w, "L%s%s%s%s%s%s\n", separator, dchan.Name, separator, dchan.ID, separator, cleanTopic)
		if err != nil {
			go i.notifyUser("Failed to write discord list.")
			log.Printf("%s(%s) failed List command [writer error]: %+v", i.Node, i.User, err)
			return
		}
	}
	_, err = fmt.Fprintf(w, "%s%s%d%s%s\n", "LIST", separator, len(chanlist), separator, time.Now().Format("01/02 15:04"))
	if err != nil {
		go i.notifyUser("Failed to write discord list.")
		log.Printf("%s(%s) failed List command [footer writer error]: %+v", i.Node, i.User, err)
		return
	}
	w.Flush()
	f.Close()
	i.sendRSCS(f.Name())

}

func History(i *CMSInput) {
	maxLineLength := 78
	count := 24
	parts := strings.Split(i.Message, " ")
	chanId := parts[0]

	if len(parts) != 2 && len(parts) != 3 {
		go i.notifyUser("Invalid arguments to History")
		log.Printf("%s(%s) failed History command [invalid argc]: %s", i.Node, i.User, i.Message)
		return
	}
	if ct, err := strconv.Atoi(parts[1]); err == nil {
		count = ct
	}
	if _, err := strconv.Atoi(chanId); err != nil {
		go i.notifyUser(fmt.Sprintf("%s was not a channel ID.", chanId))
		log.Printf("%s(%s) failed History command [not a channel ID]: %s", i.Node, i.User, i.Message)
		return
	}
	curChan, err := dg.Channel(chanId)
	if err != nil {
		go i.notifyUser(fmt.Sprintf("%s was not a valid channel ID.", chanId))
		log.Printf("%s(%s) failed History command [invalid channel ID]: %s", i.Node, i.User, i.Message)
		return
	}
	messages, err := dg.ChannelMessages(chanId, count, "", "", "")
	if err != nil {
		go i.notifyUser("Discord failed to respond to History command.")
		log.Printf("%s(%s) failed History command [discord error]: %s", i.Node, i.User, i.Message)
		return
	}
	f, err := os.CreateTemp("/tmp", fmt.Sprintf("%s_%s_%s_hist.*", i.Node, i.User, parts[0]))
	if err != nil {
		go i.notifyUser("Failed to prepare discord history.")
		log.Printf("%s(%s) failed History command [file error]: %s", i.Node, i.User, i.Message)
		return
	}
	w := bufio.NewWriter(f)
	var lines []string
	_, err = fmt.Fprintf(w, "%s%s%s%s%d%s%s\n", chanId, separator, curChan.Name, separator, count, separator, time.Now().Format("01/02 15:04"))
	if err != nil {
		go i.notifyUser("Failed to write discord history.")
		log.Printf("%s(%s) failed History command [header writer error]: %+v", i.Node, i.User, err)
		return
	}

	for j := len(messages) - 1; j >= 0; j-- {
		message := messages[j]
		if message.Author == nil {
			continue
		}
		displayName := message.Author.DisplayName()
		content := message.Content
		if message.Author.ID == config.BotID {
			match := echoRegex.FindStringSubmatch(content)
			if match != nil {
				displayName = match[1]
			}
			content = strings.ReplaceAll(content, fmt.Sprintf("`%s`", displayName), "")
		} else {
			displayName = fmt.Sprintf("D(%s)", displayName)
		}
		if len(message.Reactions) > 0 {
			for _, r := range message.Reactions {
				content = fmt.Sprintf("[+R(%s)] ", gomoji.ReplaceEmojisWithFunc(r.Emoji.Name, func(e gomoji.Emoji) string {
					return e.Slug
				})) + content
			}
		}
		if len(message.Attachments) > 0 {
			for _, a := range message.Attachments {
				content = fmt.Sprintf("[+A F(%s)] ", a.Filename) + content
			}
		}
		if len(message.Embeds) > 0 {
			content = "[+E] " + content
		}
		if len(message.StickerItems) > 0 {
			for _, s := range message.StickerItems {
				content = fmt.Sprintf("[Sticker (%s)] ", s.Name) + content
			}
		}
		if len(message.Mentions) > 0 {
			ments := message.Mentions
			for _, ment := range ments {
				if ment.ID == config.BotID {
					continue
				}
				content = strings.ReplaceAll(content, fmt.Sprintf("<@%s>", ment.ID), fmt.Sprintf("@[D(%s)]", ment.DisplayName()))
			}
		}
		if strings.Contains(content, i.User) {
			content = strings.ReplaceAll(content, i.User, fmt.Sprintf("@%s@", i.User))
		}
		content = gomoji.ReplaceEmojisWithFunc(content, func(e gomoji.Emoji) string {
			return ":" + e.Slug + ":"
		})
		fline := fmt.Sprintf("M|%s%s%s%s%s", message.Timestamp.Format("01/02 15:04"), separator, displayName, separator, content)
		remaining := []rune(fline)
		chunkSize := maxLineLength
		for len(remaining) > 0 {
			if len(remaining) < maxLineLength {
				chunkSize = len(remaining)
			}
			line := string(remaining[:chunkSize])
			lines = append(lines, line)
			remaining = remaining[chunkSize:]
		}

	}
	for _, line := range lines {
		_, err := fmt.Fprintf(w, "%s\n", line)
		if err != nil {
			go i.notifyUser("Failed to write discord history.")
			log.Printf("%s(%s) failed History command [writer error]: %s", i.Node, i.User, i.Message)
			return
		}
	}
	_, err = fmt.Fprintf(w, "%s%s%s%s%d%s%s\n", chanId, separator, curChan.Name, separator, count, separator, time.Now().Format("01/02 15:04"))
	if err != nil {
		go i.notifyUser("Failed to write discord history.")
		log.Printf("%s(%s) failed History command [footer writer error]: %+v", i.Node, i.User, err)
		return
	}
	w.Flush()
	f.Close()
	i.sendRSCS(f.Name())
}

func (i *CMSInput) sendRSCS(path string) {
	log.Println("Sending", path, "to", i.User, "at", i.Node)
	args := []string{fmt.Sprintf("%s@%s", i.User, i.Node), "-u", config.BotUser, "-fn", "discord", i.Command, path}
	cmd := exec.Command(config.NJESendPath, args...)
	err := cmd.Run()
	if err != nil {
		go i.notifyUser("RSCS Send failed.")
		log.Printf("%s(%s) failed RSCS Send: %+v", i.Node, i.User, err)
	}
	err = os.Remove(path)
	if err != nil {
		log.Printf("Failed to Remove temp file:%s for %s(%s): %+v", path, i.Node, i.User, err)
	}

}

func (i *CMSInput) notifyUser(message string) {
	time.Sleep(11 * time.Second)
	args := []string{"-u", strings.ToLower(config.BotUser), "-m", fmt.Sprintf("%s@%s", i.User, i.Node), message}
	cmd := exec.Command(config.NJETellPath, args...)
	err := cmd.Run()
	if err != nil {
		log.Printf("%s(%s) failed TELL Send: %+v", i.Node, i.User, err)
	}
}
