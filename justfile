set shell := ["bash", "-euo", "pipefail", "-c"]

plugin_name     := "learn-with-interview"
marketplace_id  := "learn-with-interview-local"
plugin_root     := justfile_directory()

default:
    @just --list

# Register this directory as a user-scope marketplace and install the plugin.
# Makes /learn-with-interview:start available in every Claude Code session.
install:
    claude plugin marketplace add '{{plugin_root}}' --scope user
    claude plugin install '{{plugin_name}}@{{marketplace_id}}'

# Uninstall plugin and remove the marketplace entry.
uninstall:
    -claude plugin uninstall '{{plugin_name}}@{{marketplace_id}}'
    -claude plugin marketplace remove '{{marketplace_id}}'

# Pull any changes from the local marketplace (e.g. after editing SKILL.md).
update:
    claude plugin marketplace update '{{marketplace_id}}'

# Show current marketplace / plugin registration.
status:
    claude plugin marketplace list
    @echo ""
    claude plugin list

# Validate the marketplace + plugin manifests.
validate:
    claude plugin validate '{{plugin_root}}'
