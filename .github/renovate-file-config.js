module.exports = {
    "autodiscover": true,
    "hostRules": [
        {
            hostType: 'github',
            matchHost: 'https://api.github.com/repos/rtbhouse-platform-engineering/renovate-scanner',
            token: process.env.RENOVATE_CONFIG_PRESET_TOKEN,
        },
        {
            hostType: 'github',
            matchHost: 'https://api.github.com/repos/rtbhouse-oeet/.github',
            token: process.env.RENOVATE_ORG_CONFIG_PRESET_TOKEN,
        },
    ],
};
