<!-- rtk-owned: shared Codex command-output policy -->

# Command output

Codex runs eligible Bash commands through RTK's PreToolUse hook. Treat its condensed
output as complete. Run commands normally and batch related inspection commands into
one call. If a result is unusable because it is empty when output was expected,
contradicts its exit status, or is garbled, rerun that command through RTK's bypass
mechanism or with a raw command only for that diagnosis.
