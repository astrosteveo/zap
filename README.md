# :wind_face: zap

> A Zsh framework as nice as a cool summer breeze

Zsh is a wonderful shell, but out-of-the-box it needs a boost. That's where zap comes
in.

zap combines some of the best parts from [Prezto][prezto] and other Zsh frameworks,
removes bloat and dependencies, and prioritizes speed and simplicity.

zap can be thought of as a fast, lightweight set of independent Zsh features, and is
designed to be one of the first things you load to build your ideal Zsh config.

Combine zap with a [plugin manager][antidote] and some [awesome
plugins](https://github.com/unixorn/awesome-zsh-plugins) and you'll have a powerful Zsh
setup that rivals anything out there.

## Project goals

zap allows you to take an _a la carte_ approach to building your ideal Zsh
configuration. Other Zsh frameworks are meant to be used wholesale and are not truly
modular. zap is different - each of its plugins works independently, and are designed
to pair well with a modern Zsh plugin manager like [antidote]. zap can be used in
whole or in part, and plays nice with other popular plugins. zap brings together core
Zsh functionality that typically is not available elsewhere as standalone plugins -
while favoring a build-your-own composable Zsh config.

## Prompt

zap comes with an (optional) [Starship][starship] prompt config.

![zap Prompt][terminal-img]

## Install

### Using a Plugin manager

If your plugin manager supports using sub-plugins, you can load zap that way as well.

[Antidote][antidote] is one such plugin manager. You can load only the parts of zap you need like so:

```shell
# .zsh_plugins.txt
# pick only the plugins you want and remove the rest
astrosteveo/zap path:plugins/color
astrosteveo/zap path:plugins/completion
astrosteveo/zap path:plugins/compstyle
astrosteveo/zap path:plugins/confd
astrosteveo/zap path:plugins/directory
astrosteveo/zap path:plugins/editor
astrosteveo/zap path:plugins/environment
astrosteveo/zap path:plugins/history
astrosteveo/zap path:plugins/homebrew
astrosteveo/zap path:plugins/macos
astrosteveo/zap path:plugins/prompt
astrosteveo/zap path:plugins/utility
astrosteveo/zap path:plugins/zfunctions
```

### Manually

Add the following snippet to your `.zshrc`:

```zsh
# Clone zap.
[[ -d ${ZDOTDIR:-~}/.zap ]] ||
  git clone --depth=1 https://github.com/astrosteveo/zap ${ZDOTDIR:-~}/.zap

# Use zstyle to specify which plugins you want. Order matters.
zap_plugins=(
  zfunctions
  directory
  editor
  history
)
zstyle ':zap:load' plugins $zap_plugins

# Source zap.
source ${ZDOTDIR:-~}/.zap/zap.zsh
```

## Plugins

- **color** - Make terminal things more colorful
- **completion** - Load and initialize the built-in zsh completion system
- **compstyle** - Load and initialize a completion style system
- **confd** - Source a Fish-like `conf.d` directory
- **directory** - Set options and aliases related to the dirstack and filesystem
- **editor** - Override and fill in the gaps of the default keybinds
- **environment** - Define common environment variables
- **history** - Load and initialize the built-in zsh history system
- **homebrew** - Functionality for users of Homebrew
- **macos** - Functionality for macOS users
- **prompt** - Load and initialize the built-in zsh prompt system
- **utility** - Common shell utilities, aimed at making cross platform work less painful
- **zfunctions** - Lazy load a Fish-like functions directory

## Customization

zap uses Zsh's zstyles to let you easily customize your config. Unlike environment variables which pollute your environment, zstyles make it easy to handle more robust configuration.

**Reminder:** `zstyle` settings need to be set prior to loading Zepyr.

The customizations are detailed below.

### Common

To selectively load plugins when sourcing zap.plugin.zsh directly, use the `zstyle ':zap:load' plugins ...` array. Order matters.

```zsh
zstyle ':zap:load' plugins \
  environment \
  homebrew \
  color \
  compstyle \
  completion \
  directory \
  editor \
  helper \
  history \
  prompt \
  utility \
  zfunctions \
  macos \
  confd
```

To use your home directory instead of using [XDG Base Directories][xdg-base-dirs]:

```zsh
zstyle ':zap:plugin:*' use-xdg-basedirs no
```

### conf.d

Change the confd directory used for conf.d:

```zsh
':zap:plugin:confd' directory ${HOME:-$ZDOTDIR}/.zshrc.d
```

### editor

Disable editor features with 'no'. Features are enabled by default:

```zsh
zstyle ':zap:plugin:editor' 'prepend-sudo' yes
zstyle ':zap:plugin:editor' 'glob-alias' no
zstyle ':zap:plugin:editor' 'magic-enter' no
zstyle ':zap:plugin:editor' 'pound-toggle' yes
zstyle ':zap:plugin:editor' 'symmetric-ctrl-z' no
```

### zfunctions

Change the zfunctions directory:

```zsh
':zap:plugin:zfunctions' directory ${HOME:-$ZDOTDIR}/.zfuncs
```

## Why don't you include...

_Q: Why don't you include programming language plugins (eg: Python, Ruby)?_ \
**A:** These kinds of plugins can be very opinionated, and are in need of lots of upkeep
from maintainers that use those languages. Language plugins are already available via
Oh-My-Zsh and Prezto, and can always be installed with [a plugin manager that supports
subplugins][antidote].

_Q: Why don't you also include popular plugins the way Prezto does (eg:
zsh-autosuggestions, zsh-history-substring-search)?_ \
**A:** These kinds of utilities are already
available as standalone plugins. zap aims to include only core Zsh functionality that
you can't already easily get via a [plugin manager][antidote], with a few exceptions for
convenience. I have experimented with including submodules similar to Prezto, but was
not happy with the result. Simpler is better.

## Credits

zap is a derivative work of the following great projects:

- [Prezto][prezto] - [MIT License][prezto-license]
- [zsh-utils][zsh-utils] - [MIT License][zsh-utils-license]
- [Oh-My-Zsh][ohmyzsh] - [MIT License][ohmyzsh-license]

[antidote]: https://antidote.sh
[ohmyzsh]: https://github.com/ohmyzsh/ohmyzsh
[ohmyzsh-license]: https://github.com/ohmyzsh/ohmyzsh/blob/master/LICENSE.txt
[prezto]: https://github.com/sorin-ionescu/prezto
[prezto-license]: https://github.com/sorin-ionescu/prezto/blob/master/LICENSE
[zsh-utils]: https://github.com/belak/zsh-utils
[zsh-utils-license]: https://github.com/belak/zsh-utils/blob/main/LICENSE
[terminal-img]: https://raw.githubusercontent.com/astrosteveo/zap/resources/img/terminal.png
[starship]: https://starship.rs
[xdg-base-dirs]: https://specifications.freedesktop.org/basedir-spec/latest/
