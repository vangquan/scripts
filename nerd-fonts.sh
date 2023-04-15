#!/bin/bash
# Nerd-font installation script

show_fonts() {
  echo "1. FiraCode"
  echo "2. Hack"
  echo "3. SourceCodePro"
  echo "4. JetBrainsMono"
}

get_font_choice() {
  echo "Select a font:"
  show_fonts
  read -p "Enter the font number: " font_choice
  case $font_choice in
    1) font="FiraCode" ;;
    2) font="Hack" ;;
    3) font="SourceCodePro" ;;
    4) font="JetBrainsMono" ;;
    *) echo "Invalid font choice. Please try again."; get_font_choice ;;
  esac
}

get_os_choice() {
  echo "Select your OS:"
  echo "1. Ubuntu"
  echo "2. Fedora"
  echo "3. Arch"
  echo "4. macOS"
  read -p "Enter the OS number: " os_choice
  case $os_choice in
    1) os="Ubuntu" ;;
    2) os="Fedora" ;;
    3) os="Arch" ;;
    4) os="macOS" ;;
    *) echo "Invalid OS choice. Please try again."; get_os_choice ;;
  esac
}

install_font() {
  echo "Installing $font for $os..."
  font_url="https://github.com/ryanoasis/nerd-fonts/raw/master/patched-fonts/$font/Regular/complete/${font// /}%20Nerd%20Font%20Complete.ttf"
  temp_font_path="/tmp/${font// /}_Nerd_Font_Complete.ttf"
  wget -q --show-progress -O "$temp_font_path" "$font_url"

  case $os in
    "Ubuntu" | "Fedora" | "Arch")
      install_dir="$HOME/.local/share/fonts"
      mkdir -p "$install_dir"
      cp "$temp_font_path" "$install_dir/"
      fc-cache -f -v
      ;;
    "macOS")
      install_dir="$HOME/Library/Fonts"
      cp "$temp_font_path" "$install_dir/"
      ;;
  esac
  echo "Successfully installed $font for $os."
}

get_font_choice
get_os_choice
install_font
