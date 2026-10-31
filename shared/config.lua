-- Drug Creator settings. Read at use time, so a live change takes effect on the next /drugCreator.
Config = Kora.config.define({
    creator = Kora.config.object({
        cacheSeconds = Kora.config.integer(30, {
            label = 'Creator data cache (seconds)',
            description = 'How long the server reuses the data it sends when an admin opens /drugCreator. Any creator save clears it at once. 0 turns the cache off.',
            min = 0, max = 600, live = true,
        }),
        chatSuggestion = Kora.config.boolean(true, {
            label = 'Show /drugCreator in chat suggestions',
            description = 'Admins who may use /drugCreator see it in the chat suggestion list; other players never do. Turn off to hide it for everyone.',
            live = true,
        }),
    }),
})
