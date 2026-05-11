#!/bin/bash
# Disable cloud services for privacy

defaults write com.apple.icloud-container-services Enabled -bool false
defaults write com.apple.assistant.support "Assistant Enabled" -bool false
defaults write com.apple.Spotlight "Item 14" -dict enabled 0
defaults write com.apple.universalaccess analyticsEnabled -bool false
defaults write com.apple.SubmitDiagInfo AutoSubmit -bool false

# Disable Siri
defaults write com.apple.Siri StatusMenuVisible -bool false
defaults write com.apple.Siri UserHasDeclinedEnable -bool true

echo "✅ Cloud services disabled"
echo "Note: Sign out of iCloud in System Settings for full privacy"
