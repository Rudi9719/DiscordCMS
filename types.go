package main

// Main config struct used for the bot
type Config struct {
	Operators      []string `toml:"operators"`
	Token          string   `toml:"token"`
	CMSUser        string   `toml:"cms_user"`
	CMSNode        string   `toml:"cms_node"`
	BotUser        string   `toml:"bot_user"`
	BotNode        string   `toml:"bot_node"`
	BotID          string   `toml:"bot_id"`
	SpoolDirectory string   `toml:"spool_directory"`
	NJEReceivePath string   `toml:"nje_recvieve_path"`
	NJESendPath    string   `toml:"nje_send_path"`
	LoopbackPort   string   `toml:"loopback_port"`
	DiscordGuild   string   `toml:"discord_guild"`
	AnnounceChan   string   `toml:"announce_chan"`
}

// CMS input originates from users talking to VMSERVE
type CMSInput struct {
	User    string
	Node    string
	Command string
	Message string
}
