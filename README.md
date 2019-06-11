# Dotfiler

[![Build Status](https://cloud.drone.io/api/badges/filipebarros/dotfiler/status.svg)](https://cloud.drone.io/filipebarros/dotfiler)

## Generate binary file

```elixir
mix escript.build
```

## Symlink files to home directory

Symlink dotfiles folder and install homebrew packages

```
./dotfiler --source <dotfiles_folder> --brew
```
