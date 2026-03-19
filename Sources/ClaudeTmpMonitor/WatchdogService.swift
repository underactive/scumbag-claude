import Foundation

// MARK: - Watchdog Service

@MainActor
class WatchdogService: ObservableObject {
    // MARK: - Settings

    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: SettingsKey.watchdogEnabled)
            if isEnabled {
                installHook()
            } else {
                uninstallHook()
            }
        }
    }

    @Published var allowedDirectories: [String] {
        didSet {
            defaults.set(allowedDirectories, forKey: SettingsKey.watchdogAllowedDirectories)
            if isEnabled {
                regenerateHookScript()
            }
        }
    }

    // MARK: - Published State

    @Published private(set) var hookInstalled: Bool = false
    @Published private(set) var lastError: String? = nil

    // MARK: - Private

    private let defaults = UserDefaults.standard
    private let fileManager = FileManager.default

    private var appSupportDir: String {
        NSHomeDirectory() + "/Library/Application Support/com.esison.claude-tmp-monitor"
    }

    private var hookScriptPath: String {
        appSupportDir + "/watchdog-hook.sh"
    }

    private var claudeSettingsPath: String {
        NSHomeDirectory() + "/.claude/settings.local.json"
    }

    // MARK: - Init

    /// Initializes from UserDefaults. Uses Published(wrappedValue:) to avoid triggering
    /// didSet side effects (installHook/regenerateHookScript) before all properties are loaded.
    init() {
        let enabled = defaults.object(forKey: SettingsKey.watchdogEnabled) as? Bool ?? false
        let dirs = defaults.object(forKey: SettingsKey.watchdogAllowedDirectories) as? [String]
            ?? ["~/Development"]
        self._isEnabled = Published(wrappedValue: enabled)
        self._allowedDirectories = Published(wrappedValue: dirs)

        checkHookStatus()

        // If enabled but hook not installed (e.g., settings.local.json was externally modified), reinstall
        if enabled && !hookInstalled {
            installHook()
        }
    }

    // MARK: - Directory Management

    func addDirectory(_ path: String) {
        // Normalize: replace home directory with ~
        let normalized = path.hasPrefix(NSHomeDirectory())
            ? "~" + path.dropFirst(NSHomeDirectory().count)
            : path

        guard !allowedDirectories.contains(normalized) else { return }
        allowedDirectories.append(normalized)
    }

    func removeDirectory(at index: Int) {
        guard index >= 0 && index < allowedDirectories.count else { return }
        allowedDirectories.remove(at: index)
    }

    // MARK: - Hook Installation

    func installHook() {
        lastError = nil

        // Ensure app support directory exists
        do {
            try fileManager.createDirectory(
                atPath: appSupportDir,
                withIntermediateDirectories: true
            )
        } catch {
            lastError = "Failed to create app support directory: \(error.localizedDescription)"
            return
        }

        // Generate and write hook script
        let script = generateHookScript()
        do {
            try script.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
        } catch {
            lastError = "Failed to write hook script: \(error.localizedDescription)"
            return
        }

        // Set executable permission
        do {
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: hookScriptPath
            )
        } catch {
            lastError = "Failed to set executable permission: \(error.localizedDescription)"
            return
        }

        // Patch Claude settings
        patchClaudeSettings(install: true)
        checkHookStatus()
    }

    func uninstallHook() {
        lastError = nil

        // Remove hook entry from Claude settings
        patchClaudeSettings(install: false)

        // Delete hook script
        try? fileManager.removeItem(atPath: hookScriptPath)

        checkHookStatus()
    }

    func checkHookStatus() {
        guard fileManager.fileExists(atPath: claudeSettingsPath),
              let data = fileManager.contents(atPath: claudeSettingsPath),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let hooks = json["hooks"] as? [String: Any],
              let preToolUse = hooks["PreToolUse"] as? [[String: Any]]
        else {
            hookInstalled = false
            return
        }

        hookInstalled = preToolUse.contains { entry in
            guard let command = entry["command"] as? String else { return false }
            return command.contains("watchdog-hook.sh")
        }
    }

    // MARK: - Private Methods

    private func regenerateHookScript() {
        guard fileManager.fileExists(atPath: hookScriptPath) else { return }

        let script = generateHookScript()
        do {
            try script.write(toFile: hookScriptPath, atomically: true, encoding: .utf8)
            lastError = nil
        } catch {
            lastError = "Failed to regenerate hook script: \(error.localizedDescription)"
        }
    }

    /// Escape a string for safe inclusion in a double-quoted bash string.
    /// Handles: backslash, double-quote, dollar, backtick.
    private func shellEscape(_ s: String) -> String {
        var result = s
        result = result.replacingOccurrences(of: "\\", with: "\\\\")
        result = result.replacingOccurrences(of: "\"", with: "\\\"")
        result = result.replacingOccurrences(of: "$", with: "\\$")
        result = result.replacingOccurrences(of: "`", with: "\\`")
        return result
    }

    private func generateHookScript() -> String {
        let expandedDirs = allowedDirectories.map { dir -> String in
            if dir.hasPrefix("~/") {
                return NSHomeDirectory() + String(dir.dropFirst(1))
            } else if dir == "~" {
                return NSHomeDirectory()
            }
            return dir
        }.map { dir -> String in
            // Ensure trailing slash for correct prefix matching
            // (prevents /DevelopmentEvil matching /Development)
            dir.hasSuffix("/") ? dir : dir + "/"
        }

        let dirsArray = expandedDirs.map { "\"\(shellEscape($0))\"" }.joined(separator: " ")
        let home = NSHomeDirectory()

        // JXA script uses single quotes in bash, so we use a heredoc to avoid escaping issues.
        // The run(argv) pattern passes JSON as an argument rather than stdin, which is more reliable.
        // Note: The backslashes in grep patterns are doubled for Swift string escaping.

        // Note: ALLOWED_DIRS entries already have trailing slashes (ensured above).
        // The prefix check `"$dir"*` is safe because dirs end with `/`.
        // shellEscape() handles special chars in dir paths.

        return """
        #!/bin/bash
        # Scumbag Claude File Write Watchdog — generated, do not edit
        # Managed by Scumbag Claude (com.esison.claude-tmp-monitor)

        ALLOWED_DIRS=(\(dirsArray))
        LOG_FILE="\(shellEscape(home))/Library/Application Support/com.esison.claude-tmp-monitor/watchdog.log"

        INPUT=$(cat)

        # Parse JSON via JXA (zero dependencies, ships with macOS)
        # Uses run(argv) pattern — JSON passed as argument, not stdin
        RESULT=$(osascript -l JavaScript -e '
        function run(argv) {
            try {
                var obj = JSON.parse(argv[0]);
                var toolName = obj.tool_name || "";
                var filePath = "";
                var command = "";
                if (obj.tool_input) {
                    filePath = obj.tool_input.file_path || "";
                    command = obj.tool_input.command || "";
                }
                return toolName + "|" + filePath + "|" + command;
            } catch(e) {
                return "error||";
            }
        }
        ' -- "$INPUT" 2>/dev/null)

        # If JXA parsing failed, allow the operation (fail open)
        if [[ -z "$RESULT" || "$RESULT" == "error||" ]]; then
            exit 0
        fi

        TOOL_NAME=$(echo "$RESULT" | head -1 | cut -d'|' -f1)
        FILE_PATH=$(echo "$RESULT" | head -1 | cut -d'|' -f2)
        COMMAND=$(echo "$RESULT" | head -1 | cut -d'|' -f3-)

        # Pure-string path normalization: resolves . and .. without touching the filesystem.
        # This prevents traversal bypasses when parent directories don't exist yet.
        normalize_path() {
            local path="$1"
            # Expand ~ to $HOME
            if [[ "$path" == ~* ]]; then
                path="${HOME}${path:1}"
            fi
            # Make absolute
            if [[ "$path" != /* ]]; then
                path="$(pwd)/$path"
            fi
            # Split on / and resolve . and ..
            local -a segments=()
            local OLD_IFS="$IFS"
            IFS="/"
            read -ra segments <<< "$path"
            IFS="$OLD_IFS"
            local -a parts=()
            for segment in "${segments[@]}"; do
                if [[ "$segment" == "." || -z "$segment" ]]; then
                    continue
                elif [[ "$segment" == ".." ]]; then
                    if [[ ${#parts[@]} -gt 0 ]]; then
                        unset "parts[${#parts[@]}-1]"
                    fi
                else
                    parts+=("$segment")
                fi
            done
            # Rejoin with leading /
            local result=""
            for part in "${parts[@]}"; do
                result="$result/$part"
            done
            echo "${result:-/}"
        }

        # Safe notification: sanitize displayed text to prevent AppleScript injection.
        notify_blocked() {
            local msg="$1"
            # Strip characters that could break AppleScript string context
            msg=$(echo "$msg" | tr -d '"\\`$')
            osascript -e "display notification \\"$msg\\" with title \\"Scumbag Claude Watchdog\\" sound name \\"Sosumi\\"" 2>/dev/null &
        }

        # Check a path against the allowlist. Returns 0 if allowed, 1 if blocked.
        # ALLOWED_DIRS entries have trailing slashes to prevent prefix confusion.
        check_allowed() {
            local check_path="$1"
            # Ensure check_path has trailing slash for prefix comparison
            [[ "$check_path" != */ ]] && check_path="$check_path/"
            for dir in "${ALLOWED_DIRS[@]}"; do
                if [[ "$check_path" == "$dir"* ]]; then
                    return 0
                fi
            done
            return 1
        }

        # For Write/Edit tools: check file_path
        if [[ "$TOOL_NAME" == "Write" || "$TOOL_NAME" == "Edit" ]]; then
            if [[ -z "$FILE_PATH" ]]; then
                exit 0
            fi

            FILE_PATH=$(normalize_path "$FILE_PATH")

            if ! check_allowed "$FILE_PATH"; then
                notify_blocked "Write blocked: $(basename "$FILE_PATH")"
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BLOCKED $TOOL_NAME $FILE_PATH" >> "$LOG_FILE" 2>/dev/null
                echo "BLOCKED by Scumbag Claude Watchdog: $FILE_PATH is outside allowed directories (${ALLOWED_DIRS[*]})" >&2
                exit 2
            fi

            exit 0
        fi

        # For Bash tool: check for destructive patterns
        if [[ "$TOOL_NAME" == "Bash" ]]; then
            if [[ -z "$COMMAND" ]]; then
                exit 0
            fi

            # Destructive patterns to check
            DESTRUCTIVE=false
            TARGET_PATH=""

            # rm / rmdir / unlink commands
            if echo "$COMMAND" | grep -qE '\\b(rm|rmdir|unlink)\\s'; then
                DESTRUCTIVE=true
                # Extract the last argument as the target path (simplified)
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '\\b(rm|rmdir|unlink)\\s+(-[a-zA-Z]*\\s+)*([^;&|]+)' | awk '{print $NF}')
            fi

            # mv / cp — last arg is destination (could overwrite or create outside allowed dirs)
            if echo "$COMMAND" | grep -qE '\\b(mv|cp)\\s'; then
                DESTRUCTIVE=true
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '\\b(mv|cp)\\s+(-[a-zA-Z]*\\s+)*([^;&|]+)' | awk '{print $NF}')
            fi

            # ln / ln -s — creating links outside allowed dirs
            if echo "$COMMAND" | grep -qE '\\bln\\s'; then
                DESTRUCTIVE=true
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '\\bln\\s+(-[a-zA-Z]*\\s+)*([^;&|]+)' | awk '{print $NF}')
            fi

            # tee — writes to files from pipelines
            if echo "$COMMAND" | grep -qE '\\btee\\s'; then
                DESTRUCTIVE=true
                # tee's file argument is the last non-flag arg
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '\\btee\\s+(-[a-zA-Z]*\\s+)*([^;&|]+)' | awk '{print $NF}')
            fi

            # dd — low-level write via of= parameter
            if echo "$COMMAND" | grep -qE '\\bdd\\s'; then
                DESTRUCTIVE=true
                TARGET_PATH=$(echo "$COMMAND" | grep -oE 'of=[^ ;&|]+' | sed 's/of=//' | head -1)
            fi

            # curl -o / wget -O — downloading to a specific path
            if echo "$COMMAND" | grep -qE '\\bcurl\\s.*-o\\s|\\bwget\\s.*-O\\s'; then
                DESTRUCTIVE=true
                # Extract path after -o/-O flag
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '(-o|-O) [^ ;&|]+' | awk '{print $2}' | head -1)
            fi

            # Redirect operators (overwrite/append)
            if echo "$COMMAND" | grep -qE '>>?[^>]'; then
                DESTRUCTIVE=true
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '>>?\\s*([^;&|\\s]+)' | sed 's/>>\\?\\s*//' | head -1)
            fi

            # chmod / chown / chflags (privilege changes)
            if echo "$COMMAND" | grep -qE '\\b(chmod|chown|chflags)\\s'; then
                DESTRUCTIVE=true
                TARGET_PATH=$(echo "$COMMAND" | grep -oE '\\b(chmod|chown|chflags)\\s+(-[a-zA-Z]*\\s+)*([^;&|]+)' | awk '{print $NF}')
            fi

            # git clean / git checkout --
            if echo "$COMMAND" | grep -qE '\\bgit\\s+(clean|checkout\\s+--)'; then
                DESTRUCTIVE=true
                TARGET_PATH=$(pwd)
            fi

            # If not destructive, allow
            if [[ "$DESTRUCTIVE" == "false" ]]; then
                exit 0
            fi

            # Clean up target path
            TARGET_PATH=$(echo "$TARGET_PATH" | xargs) # trim whitespace

            if [[ -z "$TARGET_PATH" ]]; then
                exit 0
            fi

            TARGET_PATH=$(normalize_path "$TARGET_PATH")

            # Always allow /tmp and /private/tmp
            if [[ "$TARGET_PATH" == /tmp/* || "$TARGET_PATH" == /private/tmp/* ]]; then
                exit 0
            fi

            if ! check_allowed "$TARGET_PATH"; then
                notify_blocked "Bash blocked: $(basename "$TARGET_PATH")"
                echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) BLOCKED $TOOL_NAME $COMMAND" >> "$LOG_FILE" 2>/dev/null
                echo "BLOCKED by Scumbag Claude Watchdog: $TARGET_PATH is outside allowed directories (${ALLOWED_DIRS[*]})" >&2
                exit 2
            fi

            exit 0
        fi

        # All other tools: allow
        exit 0
        """
    }

    private func patchClaudeSettings(install: Bool) {
        let claudeDir = NSHomeDirectory() + "/.claude"
        let settingsPath = claudeSettingsPath

        // Ensure ~/.claude directory exists
        if !fileManager.fileExists(atPath: claudeDir) {
            do {
                try fileManager.createDirectory(atPath: claudeDir, withIntermediateDirectories: true)
            } catch {
                lastError = "Failed to create ~/.claude directory: \(error.localizedDescription)"
                return
            }
        }

        // Read existing settings or start fresh.
        // Guard: if file exists but contains invalid JSON, abort to avoid silent data loss.
        var settings: [String: Any]
        if let data = fileManager.contents(atPath: settingsPath) {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                settings = json
            } else if data.isEmpty {
                settings = [:]
            } else {
                lastError = "~/.claude/settings.local.json contains invalid JSON — refusing to overwrite"
                return
            }
        } else {
            settings = [:]
        }

        // Get or create hooks dictionary
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Get or create PreToolUse array
        var preToolUse = hooks["PreToolUse"] as? [[String: Any]] ?? []

        // Remove any existing watchdog entries
        preToolUse.removeAll { entry in
            guard let command = entry["command"] as? String else { return false }
            return command.contains("watchdog-hook.sh")
        }

        if install {
            // Add our hook entry. The matcher restricts invocation to Write/Edit/Bash
            // tools only, avoiding the overhead of spawning osascript for read-only tools.
            let hookEntry: [String: Any] = [
                "type": "command",
                "command": hookScriptPath,
                "timeout": 5000,
                "matcher": "Write|Edit|Bash",
            ]
            preToolUse.append(hookEntry)
        }

        // Write back
        if preToolUse.isEmpty {
            hooks.removeValue(forKey: "PreToolUse")
        } else {
            hooks["PreToolUse"] = preToolUse
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        do {
            let data = try JSONSerialization.data(
                withJSONObject: settings,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: URL(fileURLWithPath: settingsPath), options: .atomic)
        } catch {
            lastError = "Failed to write Claude settings: \(error.localizedDescription)"
        }
    }
}
