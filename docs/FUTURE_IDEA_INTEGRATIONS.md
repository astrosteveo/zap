# Future Idea: Declarative Integrations

**Status**: Brainstormed, not yet implemented
**Date**: 2025-10-20
**Priority**: Nice to have

## The Problem

User's `.zshrc` gets cluttered with boilerplate:

```zsh
eval "$(starship init zsh)"
eval "$(fzf --zsh)"
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
eval "$(direnv hook zsh)"
eval "$(zoxide init zsh)"
# etc...
```

## The Solution

Clean declarative array (like `plugins=()`):

```zsh
integrations=(
  'starship'
  'fzf'
  'nvm'
  'direnv'
  'zoxide'
)
```

Zap handles the rest automatically.

## Benefits

- ✅ Clean .zshrc
- ✅ Consistent with declarative philosophy
- ✅ Helpful error messages if tool not installed
- ✅ Self-documenting (`zap integrations list`)
- ✅ Zero boilerplate

## Implementation Notes

See conversation for full design details. Key points:

- Registry in `lib/integrations.zsh`
- Check if command exists before init
- Show helpful errors
- New commands: `zap integrations list/status`

## Decision Needed

When ready, choose:
1. Document as future feature
2. Implement now
3. Create full spec

## Come Back to This Later

You were high when we discussed this. 😄
Review when sober and decide if you want it!
