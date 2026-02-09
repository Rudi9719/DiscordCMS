
# Discord CMS
![Build Status](https://github.com/Rudi9719/DiscordCMS/actions/workflows/go.yml/badge.svg)
[![CodeQL Checks](https://github.com/Rudi9719/DiscordCMS/actions/workflows/github-code-scanning/codeql/badge.svg)](https://github.com/Rudi9719/DiscordCMS/actions/workflows/github-code-scanning/codeql)
[![Dependency Graph](https://github.com/Rudi9719/DiscordCMS/actions/workflows/dependabot/update-graph/badge.svg)](https://github.com/Rudi9719/DiscordCMS/actions/workflows/dependabot/update-graph)
[![Go Reference](https://pkg.go.dev/badge/github.com/Rudi9719/DiscordCMS.svg)](https://pkg.go.dev/github.com/Rudi9719/DiscordCMS)

Discord CMS is another RSCS Bridge, this time using a [Discord Bot](https://github.com/reactiflux/discord-irc/wiki/creating-a-discord-bot-&-getting-a-token) and Go to allow Discord text conversations from CMS!

Only tested with [nje-ii](https://github.com/HackerSmacker/nje-ii) RSCS. GOPWIN interfa

**Ensure NJE-II is working on your Discord NODE and able to communicate with your RSCS node first!**
 



## Features

- List channels by messaging discord 'LIST' 
- Message history by channel by messaging discord 'HIST' followed by a channel ID
- Post messages by messaging discord 'SAY' or 'S' followed by a channel ID

## In Development

- DISCORD EXEC interface using GOPWIN


## Deployment
This project only uses the native Go build tools, and allows an optional config.toml to be specified.

```bash
  go build
  ./discordcms (/path/to/config.toml)
```

You don't even need to download the repo if your GOPATH is set!
```bash
  go install github.com/rudi9719/discordcms@latest
  discordcms (/path/to/config.toml)
```

**Ensure your config.toml is set up with your [bot token](https://github.com/reactiflux/discord-irc/wiki/creating-a-discord-bot-&-getting-a-token) and discord guild before launching!**


## License

[WTFPL](https://choosealicense.com/licenses/wtfpl/)


## Used By

This project is used by the following:

- PUBVM


## Support

No


## Acknowledgements

 - [The PUBVM Team](https://www.pubvm.org)
 - [NJE-ii](https://github.com/HackerSmacker/nje-ii)
 - [BurntSishi/toml ](github.com/BurntSushi/toml)
 - [bwmarrin/discordgo](https://github.com/bwmarrin/discordgo)
 - [forPelevin/gomoji](https://github.com/forPelevin/gomoji)
