---
name: setup
description: Sets up a Mac for ButterCut. Installs all required dependencies (Homebrew, Ruby, Python, FFmpeg, WhisperX) and generates machine config. Use when user says "install buttercut", "set up my mac", "get started", "first time setup", "install dependencies", "check my installation", or "configure this machine".
---

# Skill: Mac Setup

Sets up a Mac for ButterCut. Handles dependencies, machine config, and skill symlinks.

## Step 1: Check Current State

Run the verification script to see what's already installed:

```bash
ruby .claude/skills/setup/verify_install.rb
```

If all dependencies pass, skip to Step 4 (machine config).

## Step 2: Ask User Preference

If dependencies are missing, use AskUserQuestion:

```
Question: "How would you like to install ButterCut?"
Header: "Install type"
Options:
  1. "Simple (recommended)" - "Fully automatic setup. We'll install everything for you using sensible defaults."
  2. "Advanced" - "For developers who want control. You manage Ruby/Python versions with your preferred tools."
```

## Step 3: Run Appropriate Setup

Based on user choice:

- **Simple**: Read and follow `.claude/skills/setup/simple-setup.md`
- **Advanced**: Read and follow `.claude/skills/setup/advanced-setup.md`

## Step 4: Generate Machine Config

Generate `~/.buttercut-env.json` for this machine (auto-detects hostname, paths, vault location):

```bash
ruby .claude/skills/setup/configure-machine.rb
```

This creates the config, sets up the skill symlink, and tells you what needs manual attention (like the Gemini API key).

If the config already exists, the script will show it and ask before overwriting.

## Step 5: Verify Everything

Run verification again:

```bash
ruby .claude/skills/setup/verify_install.rb
```

Then confirm machine config exists:

```bash
cat ~/.buttercut-env.json
```

Report results to user. If Gemini API key is still placeholder, remind them to set it.
