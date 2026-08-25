import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// edb-diff-files opens $VISUAL (then $EDITOR) in the active terminal. Default
// to Neovim while allowing an explicitly supplied $VISUAL to take precedence.
export default function diffFilesNvimDefault(_pi: ExtensionAPI) {
  process.env.VISUAL ||= "nvim";
}
