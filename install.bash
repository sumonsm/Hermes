#!/usr/bin/env bash
INSTALL_DIR=`pwd`
TIMESTAMP=`date +%Y%m%d%H%M%S`
LOGFILE=$INSTALL_DIR/install-$TIMESTAMP.log
TEMP_MANIFEST=/tmp/$USER-hermes_custom_manifest
touch $TEMP_MANIFEST

function log () {
  echo -e $@ >> $LOGFILE
}

function handle_error () {
  if [ "$?" != "0" ]; then
    echo -e "$2 $1"
    exit 1
  fi
}

function customise_manifest () {
  CONTENT=`cat $INSTALL_DIR/dotfile_manifest`
  for file in $CONTENT; do
    if [ -e $HOME/.$file ]
      then
        echo "$HOME/.$file" >> $TEMP_MANIFEST
    fi
  done
}

function link_dotfiles () {
  CONTENT=`cat $INSTALL_DIR/dotfile_manifest`
  for file in $CONTENT; do
    SOURCE_FILE=$HOME/.hermes/hermes/$file
    TARGET_FILE=$HOME/.$file
    if [ -e $SOURCE_FILE ]; then
      echo "Symlinking hermes dotfile $file to $HOME"
      ln -sf $SOURCE_FILE $TARGET_FILE
      handle_error "Could not link to $TARGET_FILE" "Symlinking:"
    fi
  done
}

function check_command_dependency () {
  $1 --version &> /dev/null
  handle_error $1 'There was a problem with:'
}

function install_homebrew () {
  log "Checking for the presence of $1"
  HOMEBREW_OUTPUT=`brew install $1 2>&1`
  handle_error $1 "Homebrew had a problem\n($HOMEBREW_OUTPUT):"
}

function remove_homebrew () {
  log "Removing homebrew recipe $1"
  HOMEBREW_OUTPUT=`brew uninstall $1 2>&1`
  handle_error $1 "Homebrew had a problem while removing\n($HOMEBREW_OUTPUT):"
}

function backup_dotfiles () {
  customise_manifest
  cd $HOME
  tar zcvf $INSTALL_DIR/dotfile_backup-$TIMESTAMP.tar.gz -I $TEMP_MANIFEST >> $LOGFILE 2>&1
  handle_error "($?)" "Backup failed, please see the install log for details"
}

function homebrew_checkinstall_recipe () {
  brew list $1
  if [ $? == 0 ]; then
    echo "Your $1 installation is fine. Doing nothing."
  else
    install_homebrew $1
  fi
}

function homebrew_checkinstall_vim () {
  SKIP=`vim --version | grep '+clipboard'`
  if [[ "$SKIP" != "" ]]; then
    echo "Your vim installation is fine. Doing nothing."
  else
    brew list macvim
    if [ $? == 0 ]; then
      remove_homebrew "macvim"
    else
      echo "No vim to remove"
    fi
    install_homebrew $1
  fi
}

function homebrew_dependencies () {
  while read recipe; do
    echo "Installing recipe $recipe"
    if [[ $recipe == macvim* ]]; then
      homebrew_checkinstall_vim $recipe
    else
      homebrew_checkinstall_recipe $recipe
    fi
  done < "$INSTALL_DIR/homebrew_dependencies"
}

log "Starting Hermes installation"

backup_dotfiles

# Check for dependencies
check_command_dependency brew
check_command_dependency rvm

homebrew_dependencies

link_dotfiles