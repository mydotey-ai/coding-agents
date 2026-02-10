#!/bin/bash

set -x

source ~/bin/enable-proxy

# 1. 更新Homebrew本身
brew update

# 2. 升级所有包到最新版本
brew upgrade

# 3. 检查健康状态并修复问题
brew doctor

# 4. 清理过期的包
brew cleanup

# 5. 清理Cask应用
brew cleanup --cask

# 6. 移除孤儿依赖
brew autoremove

# 7. 清理缓存（可选）
brew cleanup -s

# 8. 强制清理所有包的旧版本
brew cleanup --prune=all
