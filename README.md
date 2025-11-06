# zap

> A modern, minimal Zsh framework

Zsh is a wonderful shell that is unfortunately overlooked due to its cryptic state with the out of the box experience (OOBE).

## What is a shell?

Before you can determine if Zsh is right for you first you must understand what a shell is, what one isn't, and why you should care if you use `zsh` or any other shell such as `ksh`, `fish`, `bash`.

> [!INFO]
> Apple made the switch to zsh in macos starting with `macOS Catalina` in 2019.

### Simple Analogy

Picture your computer as a library, and the files and directories are the various sections and programs are books on the shelf. At the library when you want a specific book you can request it from a librarian who will assist you with locating that book.

Computer shells do the same thing. You want to perform an action such as printing text to the screen with the `echo` command. Instead of giving you direct access to the kernel, an API is exposed that the shell interfaces with that takes your abstract commands and translates them into system calls that the kernel executes, and then returns a response back to the user, allowing the user to see the output on the terminal.

> A computer shell is simply a program that makes API calls to the kernel. Nothing more. Nothing less. It acts as an intermediary between the user and the kernel.

## What's a Terminal Then?

A terminal, also known as a `terminal emulator`, is a text-based interface for users to interact with the operating system through system calls that the shell makes through the API exposed by the kernel. Terminal and shell are often interchangably used but they serve entirely different roles.

If the shell makes API calls to the kernel's API, then the terminal draws the output on the screen. Terminals are programs such as `Gnome Terminal`, `Konsole`, `Alacritty`, `Kitty`, and `Wezterm` to name the most popular ones. If you're on macOS, then `iTerm2` likely resonates with you, as it is the terminal emulator that ships by default with modern versions of macOS.

## Why Zsh?

Some distinguishing features of Zsh compared to other shells like Bash or Fish include:

### Advanced Globbing

Zsh provides comprehensive options for pattern matching and file selection, such as recursive globbing with `**`.

### Customization

Zsh is highly configurable with hooks, themes, and modules, making it suitable for both casual users and power users.

### Programmable Autocompletion

With granular control over autocomplete rules, Zsh allows enhanced customization for completing commands, arguments, and paths.

By abstracting complex system-level operations into a user-friendly interface, the shell becomes an essential tool for interacting with Unix-like systems.

In computing, the shell is a program that helps you interact with your computer by typing commands. It's like a translator between you and the computer's inner workings. Zsh is one type of shell, and it's designed to be efficient, customizable, and make your work easier.

Zsh is

## Where does zap's role come in?

zap combines some of the best parts from [Prezto][prezto] and other Zsh frameworks,
removes bloat and dependencies, and prioritizes speed and simplicity.

The goal is to give a baseline to start from that has sane defaults such as:

- Keybinds
- Completion
- History
- Prompting


zap can be thought of as a fast, lightweight set of independent Zsh features, and is
designed to be one of the first things you load to build your ideal Zsh config.

Combine zap with a plugin manager, or even manually source them yourself in your `${HOME}/.zshrc` and some [awesome
plugins](https://github.com/unixorn/awesome-zsh-plugins) and you'll have a powerful Zsh
setup that rivals anything out there.

- No updates. Aside from bug fixes and feature requests, you never have to worry about your plugin manager being updated. zap works by simply:

1. Cloning the plugin repo.
2. Installing the plugin.
3. Loading the plugin.

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

## Credits

zap is a derivative work of the following great projects:

- [Zephyr][zephyr] - [MIT License][zephyr-license]
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
[zephyr]: https://github.com/mattmc3/zephyr
[zephyr-license]: https://github.com/mattmc3/zephyr/blob/main/LICENSE
