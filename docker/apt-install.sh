#!/usr/bin/env bash
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
set -euo pipefail

# Ensure this script is run as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Check for required arguments
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <package1> [<package2> ...]" >&2
  exit 1
fi

# Colors for better logging (optional)
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

# Install packages with clean-up
echo -e "${GREEN}Updating package lists...${RESET}"
apt-get update -qq

echo -e "${GREEN}Installing packages: $@${RESET}"
apt-get install -yqq --no-install-recommends "$@"

# Install Chrome for PDF export if not already installed
if ! command -v google-chrome &> /dev/null && ! command -v chromium &> /dev/null && ! command -v chromium-browser &> /dev/null; then
    echo -e "${GREEN}Installing Chrome/Chromium for PDF export...${RESET}"
    
    # First install wget and curl if not available
    apt-get install -yqq --no-install-recommends wget curl ca-certificates gnupg || true
    
    # Try multiple Chromium installation methods
    CHROMIUM_INSTALLED=false
    
    # Method 1: Try standard chromium package
    if apt-get install -yqq --no-install-recommends chromium 2>/dev/null; then
        echo -e "${GREEN}Chromium installed successfully${RESET}"
        CHROMIUM_INSTALLED=true
    # Method 2: Try chromium-browser (older distributions)
    elif apt-get install -yqq --no-install-recommends chromium-browser 2>/dev/null; then
        echo -e "${GREEN}Chromium-browser installed successfully${RESET}"
        CHROMIUM_INSTALLED=true
    # Method 3: Try Google Chrome as fallback
    elif curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg 2>/dev/null; then
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list
        apt-get update -qq 2>/dev/null || true
        if apt-get install -yqq --no-install-recommends google-chrome-stable 2>/dev/null; then
            echo -e "${GREEN}Google Chrome installed successfully${RESET}"
            CHROMIUM_INSTALLED=true
        fi
    fi
    
    # Method 4: Try snap installation as last resort
    if [ "$CHROMIUM_INSTALLED" = false ]; then
        echo -e "${RED}Standard package installation failed, trying alternative methods...${RESET}"
        # Install chromium via snap if available
        if command -v snap &> /dev/null; then
            snap install chromium 2>/dev/null && CHROMIUM_INSTALLED=true || true
        fi
    fi
    
    # Method 5: Download and install Chrome manually
    if [ "$CHROMIUM_INSTALLED" = false ]; then
        echo -e "${RED}Trying manual Chrome installation...${RESET}"
        cd /tmp
        if wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb 2>/dev/null; then
            if dpkg -i google-chrome-stable_current_amd64.deb 2>/dev/null || apt-get install -f -yqq 2>/dev/null; then
                echo -e "${GREEN}Chrome installed manually${RESET}"
                CHROMIUM_INSTALLED=true
            fi
            rm -f google-chrome-stable_current_amd64.deb
        fi
    fi
    
    if [ "$CHROMIUM_INSTALLED" = false ]; then
        echo -e "${RED}WARNING: Could not install Chrome/Chromium. PDF exports may not work.${RESET}"
        echo -e "${RED}You may need to install Chrome/Chromium manually in your production environment.${RESET}"
    fi
fi

echo -e "${GREEN}Autoremoving unnecessary packages...${RESET}"
apt-get autoremove -y

echo -e "${GREEN}Cleaning up package cache and metadata...${RESET}"
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/* /var/tmp/*

echo -e "${GREEN}Installation and cleanup complete.${RESET}"
