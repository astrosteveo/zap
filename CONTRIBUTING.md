# Contributing

## Setup

```bash
git clone https://github.com/astrosteveo/zap.git
cd zap

# Check syntax
zsh -n zap.zsh lib/*.zsh

# Run tests (requires bats)
bats tests/integration/*.bats
```

## Structure

```
zap/
├── zap.zsh           # Main entry point
├── lib/
│   ├── defaults.zsh  # Sensible defaults (keybindings, history, PATH, ls)
│   ├── loader.zsh    # Plugin sourcing
│   ├── downloader.zsh # Git operations
│   ├── parser.zsh    # Plugin spec parsing
│   ├── framework.zsh # Oh-My-Zsh/Prezto compat
│   ├── updater.zsh   # Plugin updates
│   ├── prompt.zsh    # Built-in prompt
│   ├── compfix.zsh   # Completion security
│   ├── termsupport.zsh # Terminal titles
│   └── utils.zsh     # Utilities
└── tests/
```

## Guidelines

- Keep it simple
- Prefix functions with `_zap_`
- Quote your variables
- Don't break shell startup on errors
- Test your changes

## Pull Requests

1. Fork & branch
2. Make changes
3. Test: `zsh -n zap.zsh lib/*.zsh`
4. Submit PR

MIT License
