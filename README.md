# Gemini Project

This project provides a set of tools and scripts for interacting with and managing files and directories.

## Overview

The Gemini project includes shell scripts and supporting libraries designed to facilitate various file system operations. It provides tools for file manipulation, directory management, and information retrieval. The `tools/` directory contains individual tool implementations, while the `lib/` directory offers reusable functions and context management.

## Directory Structure

*   `gemini/` (Root directory):
    *   `README.md`: This file, providing an overview of the project.
    *   `HELLO.txt`: A simple text file containing "Hello, world!", likely for testing purposes.
    *   `execute_tool.sh`: A general script for executing tools within the Gemini environment. (Note: This script is not the primary entry point for the chat system.)
    *   `fixed__gemini_chat.sh`: A shell script for Gemini chat, potentially representing a corrected or improved version.
    *   `format_md.sh`: A script to automatically format Markdown files within the project.
    *   `gemini_chat.sh`: The main script for interacting with the Gemini chat system.
    *   `lib/`: Contains supporting library scripts.
        *   `context.sh`: Likely handles context management for tool execution.
        *   `input.sh`: Potentially manages user input and argument parsing.
        *   `system.sh`: Provides system-level functions and utilities.
        *   `tools.sh`: Likely contains functions for tool invocation and management.
    *   `test_gemini.sh`: A script for running tests against the Gemini system.
    *   `tools/`: Contains individual tool implementations.
        *   `cat/`: Implementation of the `cat` tool (concatenate and display files).
        *   `date/`: Implementation of the `date` tool (display current date and time).
        *   `list_tools/`: Implementation of a tool to list available tools.
        *   `ls/`: Implementation of the `ls` tool (list directory contents).
        *   `mkdir/`: Implementation of the `mkdir` tool (create directories).
        *   `ping_pong/`: Implementation of a simple ping-pong testing tool.
        *   `pwd/`: Implementation of the `pwd` tool (print working directory).
        *   `read_file/`: Implementation of the `read_file` tool (read file contents).
        *   `search/`: Implementation of the `search` tool (perform internet searches).
        *   `tree/`: Implementation of the `tree` tool (display directory structure as a tree).
        *   `write_file/`: Implementation of the `write_file` tool (write content to a file).

## Usage

To start the Gemini chat system, execute the `gemini_chat.sh` script. This script provides an interactive chat interface. The `execute_tool.sh` script is a general script for executing tools within the Gemini environment, but it is not the primary entry point for the chat system. Consult the individual tool directories within `tools/` for specific usage instructions for each tool.