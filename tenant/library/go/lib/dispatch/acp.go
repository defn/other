// ACP integration: drive Claude Code via the Agent Client Protocol
// instead of shelling out to `claude -p`. Trade-offs vs. --agent-cmd:
//
//   shell-out (--agent-cmd):
//     + simple: subprocess + git status detect
//     + zero deps
//     - no streaming events, no programmatic permission control
//     - --allow-dangerously-skip-permissions to avoid hangs
//
//   ACP (--acp-prompt):
//     + structured streaming: tool calls, edits, agent thoughts
//     + programmatic permission callbacks (auto-allow inside the
//       worktree's isolation boundary)
//     + clean cancel via ctx
//     - extra dep: github.com/coder/acp-go-sdk (pre-1.0)
//     - requires `claude-agent-acp` on PATH (mise-pinned in
//       kernel/schema/versions.cue, npm name
//       @zed-industries/claude-agent-acp -- the rename of
//       @zed-industries/claude-code-acp at v0.17.0)
//
// One ACP subprocess per session is the practical model -- the
// bridge inherits one OS cwd at spawn, so we fork one bridge per
// worktree.

package dispatch

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"

	acp "github.com/coder/acp-go-sdk"
)

// agentRunInfo carries the post-run telemetry from one ACP
// dispatch. SessionID is always populated on success (and after
// session creation even on Prompt-time failure). Usage counts and
// cost are populated when the bridge emits them via the unstable
// PromptResponse.Usage / SessionUsageUpdate.cost channels; they
// stay zero/empty otherwise.
type agentRunInfo struct {
	SessionID        string
	InputTokens      int
	OutputTokens     int
	CacheReadTokens  int
	CacheWriteTokens int
	ThoughtTokens    int
	TotalTokens      int
	CostAmount       float64
	CostCurrency     string
}

// runAgentACP drives Claude Code via the ACP bridge for one
// dispatched brick. Returns an agentRunInfo with the resumable
// session ID (suitable for `claude --resume <id>` debugging) and
// any usage/cost telemetry the bridge surfaced, plus any
// subprocess / protocol error. The session ID is recorded on
// success before the prompt response, so even a Prompt-time
// failure leaves behind a resumable session in the returned info.
func runAgentACP(ctx context.Context, bridge []string, prompt, slug, runID, workDir, logPath, plansDir string) (info agentRunInfo, err error) {
	tmpl := strings.NewReplacer(
		"{{slug}}", slug,
		"{{worktree}}", workDir,
		"{{run}}", runID,
		"{{plans_dir}}", plansDir,
	)
	resolvedPrompt := tmpl.Replace(prompt)
	if resolvedPrompt == "" {
		return info, fmt.Errorf("acp: empty prompt after template substitution")
	}

	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
		return info, fmt.Errorf("acp: mkdir log dir: %w", err)
	}
	logFile, err := os.Create(logPath)
	if err != nil {
		return info, fmt.Errorf("acp: create log: %w", err)
	}
	defer logFile.Close()

	// Drop a project-local settings file in the worktree that
	// overrides settings the bridge's stricter SDK rejects. The
	// user's real ~/.claude/settings.json may have CLI-only values
	// like `permissions.defaultMode: "auto"` (valid for interactive
	// claude, rejected by the Claude Agent SDK which accepts only
	// default / acceptEdits / dontAsk / plan / bypassPermissions).
	//
	// Settings precedence in the SDK is user -> project -> local ->
	// enterprise; later overrides earlier. We write the worktree's
	// .claude/settings.json so the bad user setting is shadowed
	// without touching the user's real config or its OAuth tokens.
	projectClaudeDir := filepath.Join(workDir, ".claude")
	if err := os.MkdirAll(projectClaudeDir, 0o755); err != nil {
		return info, fmt.Errorf("acp: mkdir project .claude: %w", err)
	}
	settingsJSON := `{"permissions":{"defaultMode":"bypassPermissions"}}`
	if err := os.WriteFile(filepath.Join(projectClaudeDir, "settings.json"), []byte(settingsJSON), 0o644); err != nil {
		return info, fmt.Errorf("acp: write project settings: %w", err)
	}

	cmd := exec.CommandContext(ctx, bridge[0], bridge[1:]...)
	cmd.Dir = workDir
	cmd.Stderr = logFile
	// Scrub the bridge's environment of every variable that bakes
	// in the COORDINATOR's path, then re-anchor PWD at workDir.
	// Without this, the bridge/Claude Code resolves "the project
	// root" via inherited env (PWD, MISE_PROJECT_ROOT, etc.) and
	// some sessions write into the coordinator's main checkout
	// instead of the worktree (TODO 1b, observed 2026-05-09 on
	// run 20260510T062330Z + 20260510T064657Z; 2-of-4 then 3-of-4
	// leaked respectively, despite explicit cmd.Dir = workDir and
	// ACP NewSession Cwd = workDir). cmd.Dir alone affects only
	// the child's getcwd(); tools that read PWD or MISE_*
	// shortcut around it.
	//
	// Also strips CLAUDECODE so the child claude doesn't detect
	// itself as nested when the dispatcher itself runs inside a
	// coordinator Claude Code session.
	cmd.Env = filterEnv(os.Environ(),
		"CLAUDECODE",
		"PWD", "OLDPWD",
		"MISE_PROJECT_ROOT", "MISE_ORIGINAL_CWD", "MISE_CONFIG_ROOT",
		"MISE_TASK_DIR", "MISE_TASK_FILE", "MISE_TASK_NAME",
		"CLAUDE_CODE_SESSION_ID", "CLAUDE_CODE_ENTRYPOINT",
		"CLAUDE_CODE_EXECPATH", "CLAUDE_PROJECT_DIR",
		"GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
	)
	cmd.Env = append(cmd.Env, "PWD="+workDir)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return info, fmt.Errorf("acp: stdin pipe: %w", err)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return info, fmt.Errorf("acp: stdout pipe: %w", err)
	}
	if err := cmd.Start(); err != nil {
		return info, fmt.Errorf("acp: start bridge: %w", err)
	}
	defer func() {
		_ = stdin.Close()
		// Best-effort kill so an orphaned bridge doesn't linger.
		_ = cmd.Process.Kill()
		_, _ = cmd.Process.Wait()
	}()

	client := &acpClient{log: logFile, slug: slug, workDir: workDir}
	conn := acp.NewClientSideConnection(client, stdin, stdout)

	if _, err := conn.Initialize(ctx, acp.InitializeRequest{
		ProtocolVersion: acp.ProtocolVersionNumber,
		ClientCapabilities: acp.ClientCapabilities{
			Fs: acp.FileSystemCapabilities{ReadTextFile: true, WriteTextFile: true},
		},
	}); err != nil {
		return info, fmt.Errorf("acp: initialize: %w", err)
	}

	sess, err := conn.NewSession(ctx, acp.NewSessionRequest{
		Cwd:        workDir,
		McpServers: []acp.McpServer{},
	})
	if err != nil {
		return info, fmt.Errorf("acp: new session: %w", err)
	}
	info.SessionID = string(sess.SessionId)
	sessionID := info.SessionID
	// Record the session ID alongside the log so the user can
	// `claude --resume <id>` later for debugging or continuation.
	// One file per slug, sibling to the per-agent log file.
	sessionIDPath := filepath.Join(filepath.Dir(logPath), "..", "sessions", slug+".id")
	if err := os.MkdirAll(filepath.Dir(sessionIDPath), 0o755); err == nil {
		_ = os.WriteFile(sessionIDPath, []byte(sessionID+"\n"), 0o644)
	}
	fmt.Fprintf(logFile, "[acp] session %s in %s\n", sessionID, workDir)
	fmt.Fprintf(logFile, "[acp] prompt: %s\n", resolvedPrompt)
	// Surface the session ID on the coordinator's stdout so the
	// user sees it without having to grep logs.
	fmt.Printf("✓ acp: %s session=%s\n", slug, sessionID)

	resp, err := conn.Prompt(ctx, acp.PromptRequest{
		SessionId: sess.SessionId,
		Prompt:    []acp.ContentBlock{acp.TextBlock(resolvedPrompt)},
	})
	if err != nil {
		// Even on prompt failure, surface whatever streaming
		// telemetry we managed to collect via SessionUpdate.
		client.populateInfo(&info)
		return info, fmt.Errorf("acp: prompt: %w", err)
	}
	// PromptResponse.Usage is the canonical, per-turn breakdown
	// (input/output/cache/thought). SessionUsageUpdate (streaming)
	// carries cost + context-window size; the client struct holds
	// the most recent one. Both are unstable in the ACP spec --
	// missing either is expected on older bridges.
	client.populateInfo(&info)
	if resp.Usage != nil {
		info.InputTokens = resp.Usage.InputTokens
		info.OutputTokens = resp.Usage.OutputTokens
		info.TotalTokens = resp.Usage.TotalTokens
		if resp.Usage.CachedReadTokens != nil {
			info.CacheReadTokens = *resp.Usage.CachedReadTokens
		}
		if resp.Usage.CachedWriteTokens != nil {
			info.CacheWriteTokens = *resp.Usage.CachedWriteTokens
		}
		if resp.Usage.ThoughtTokens != nil {
			info.ThoughtTokens = *resp.Usage.ThoughtTokens
		}
	}
	return info, nil
}

// acpClient implements acp.Client. It logs every session update
// to the per-agent log file and auto-approves permission requests
// (the worktree boundary is the safety net -- isolated checkout,
// merged via the coordinator at end).
//
// The client also accumulates the bridge's UNSTABLE cost/usage
// telemetry: SessionUsageUpdate events (cost + context window)
// arrive during the turn, and the final per-turn token breakdown
// arrives via PromptResponse.Usage after conn.Prompt returns. The
// mu mutex guards both log writes and these counters because
// SessionUpdate is invoked on the SDK's internal goroutine.
type acpClient struct {
	log              io.Writer
	slug             string
	workDir          string
	mu               sync.Mutex
	costAmount       float64
	costCurrency     string
	contextSize      int
	contextUsed      int
	usageUpdateCount int
}

// populateInfo copies the bridge-streamed cost / context fields
// into info. PromptResponse.Usage (caller-side) overlays the
// per-turn token breakdown after this returns.
func (c *acpClient) populateInfo(info *agentRunInfo) {
	c.mu.Lock()
	defer c.mu.Unlock()
	info.CostAmount = c.costAmount
	info.CostCurrency = c.costCurrency
}

var _ acp.Client = (*acpClient)(nil)

func (c *acpClient) write(format string, args ...any) {
	c.mu.Lock()
	defer c.mu.Unlock()
	fmt.Fprintf(c.log, format, args...)
}

func (c *acpClient) SessionUpdate(_ context.Context, params acp.SessionNotification) error {
	u := params.Update
	switch {
	case u.AgentMessageChunk != nil && u.AgentMessageChunk.Content.Text != nil:
		c.write("[agent] %s", u.AgentMessageChunk.Content.Text.Text)
	case u.UserMessageChunk != nil && u.UserMessageChunk.Content.Text != nil:
		c.write("[user] %s\n", u.UserMessageChunk.Content.Text.Text)
	case u.AgentThoughtChunk != nil && u.AgentThoughtChunk.Content.Text != nil:
		c.write("[think] %s", u.AgentThoughtChunk.Content.Text.Text)
	case u.ToolCall != nil:
		title := ""
		if u.ToolCall.Title != "" {
			title = u.ToolCall.Title
		}
		c.write("[tool] %s (%s)\n", title, u.ToolCall.Status)
	case u.ToolCallUpdate != nil:
		c.write("[tool-update] %s -> %v\n", u.ToolCallUpdate.ToolCallId, u.ToolCallUpdate.Status)
	case u.Plan != nil:
		c.write("[plan] %d entries\n", len(u.Plan.Entries))
	case u.UsageUpdate != nil:
		c.recordUsage(u.UsageUpdate)
	}
	return nil
}

// recordUsage stores the most recent SessionUsageUpdate (cost +
// context window). Only the last value is retained: the bridge
// emits these incrementally as the turn progresses, and the final
// one is the cumulative session total -- which is what we want to
// surface on the BrickResult.
func (c *acpClient) recordUsage(u *acp.SessionUsageUpdate) {
	if u == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.usageUpdateCount++
	c.contextSize = u.Size
	c.contextUsed = u.Used
	if u.Cost != nil {
		c.costAmount = u.Cost.Amount
		c.costCurrency = u.Cost.Currency
	}
	// Don't write a log line per usage update -- too noisy on
	// long turns. The per-brick BrickResult carries the final
	// numbers; the end-of-run summary aggregates.
}

// RequestPermission auto-approves: each agent runs in its own
// worktree, so there's no shared state to corrupt. The merge step
// is the gate that lets the coordinator review what changed before
// it lands on HEAD.
//
// If the agent requests a permission with no offered options
// (shouldn't happen per protocol but defensive), reject.
func (c *acpClient) RequestPermission(_ context.Context, params acp.RequestPermissionRequest) (acp.RequestPermissionResponse, error) {
	if len(params.Options) == 0 {
		return acp.RequestPermissionResponse{
			Outcome: acp.RequestPermissionOutcome{Cancelled: &acp.RequestPermissionOutcomeCancelled{}},
		}, nil
	}
	// Prefer an "allow"-shaped option; fall back to the first.
	chosen := params.Options[0]
	for _, opt := range params.Options {
		if opt.Kind == acp.PermissionOptionKindAllowAlways || opt.Kind == acp.PermissionOptionKindAllowOnce {
			chosen = opt
			break
		}
	}
	c.write("[perm] auto-allow %q via %s\n", chosen.Name, chosen.Kind)
	return acp.RequestPermissionResponse{
		Outcome: acp.RequestPermissionOutcome{
			Selected: &acp.RequestPermissionOutcomeSelected{OptionId: chosen.OptionId},
		},
	}, nil
}

func (c *acpClient) ReadTextFile(_ context.Context, params acp.ReadTextFileRequest) (acp.ReadTextFileResponse, error) {
	if err := c.fenceWorkDir(params.Path, "ReadTextFile"); err != nil {
		return acp.ReadTextFileResponse{}, err
	}
	b, err := os.ReadFile(params.Path)
	if err != nil {
		return acp.ReadTextFileResponse{}, err
	}
	return acp.ReadTextFileResponse{Content: string(b)}, nil
}

func (c *acpClient) WriteTextFile(_ context.Context, params acp.WriteTextFileRequest) (acp.WriteTextFileResponse, error) {
	if err := c.fenceWorkDir(params.Path, "WriteTextFile"); err != nil {
		return acp.WriteTextFileResponse{}, err
	}
	if err := os.MkdirAll(filepath.Dir(params.Path), 0o755); err != nil {
		return acp.WriteTextFileResponse{}, err
	}
	if err := os.WriteFile(params.Path, []byte(params.Content), 0o644); err != nil {
		return acp.WriteTextFileResponse{}, err
	}
	return acp.WriteTextFileResponse{}, nil
}

// fenceWorkDir is the dispatcher's hard isolation fence: any path
// the bridge sends through ACP file ops must resolve under the
// session's workDir (the agent's own worktree). Without this fence
// a confused agent can resolve a relative path against the wrong
// root and write into the coordinator's main checkout (TODO 1b,
// observed 2026-05-09 with 2 of 4 parallel agents).
//
// Resolves symlinks on both sides before the prefix comparison so
// /var/folders -> /private/var/folders style indirection (macOS
// /tmp) doesn't trip a false reject. Path itself need not exist
// (Write creates new files); only the longest existing prefix is
// resolved.
func (c *acpClient) fenceWorkDir(path, op string) error {
	if !filepath.IsAbs(path) {
		return fmt.Errorf("acp: %s path must be absolute: %s", op, path)
	}
	if c.workDir == "" {
		return nil
	}
	wd, err := filepath.EvalSymlinks(c.workDir)
	if err != nil {
		return fmt.Errorf("acp: %s resolve workDir %s: %w", op, c.workDir, err)
	}
	resolved := resolveExistingPrefix(filepath.Clean(path))
	rel, err := filepath.Rel(wd, resolved)
	if err != nil || rel == ".." || strings.HasPrefix(rel, ".."+string(filepath.Separator)) {
		c.write("[fence] %s rejected out-of-worktree path: %s (workDir=%s)\n", op, path, wd)
		return fmt.Errorf("acp: %s rejected: path %s falls outside session worktree %s", op, path, wd)
	}
	return nil
}

// resolveExistingPrefix walks upward until a path component exists,
// EvalSymlinks-resolves that prefix, then re-joins the unresolved
// suffix. Lets us fence a Write target that doesn't yet exist
// without giving up symlink resolution on the parent that does.
func resolveExistingPrefix(p string) string {
	suffix := ""
	for cur := p; ; {
		if resolved, err := filepath.EvalSymlinks(cur); err == nil {
			if suffix == "" {
				return resolved
			}
			return filepath.Join(resolved, suffix)
		}
		parent := filepath.Dir(cur)
		if parent == cur {
			return p
		}
		suffix = filepath.Join(filepath.Base(cur), suffix)
		cur = parent
	}
}

// Terminal capabilities are not advertised in InitializeRequest,
// so the bridge shouldn't request them. These no-ops satisfy the
// interface; if invoked unexpectedly, return an error rather than
// silently lying about success.

func (c *acpClient) CreateTerminal(context.Context, acp.CreateTerminalRequest) (acp.CreateTerminalResponse, error) {
	return acp.CreateTerminalResponse{}, errors.New("acp: terminal capability not enabled")
}
func (c *acpClient) TerminalOutput(context.Context, acp.TerminalOutputRequest) (acp.TerminalOutputResponse, error) {
	return acp.TerminalOutputResponse{}, errors.New("acp: terminal capability not enabled")
}
func (c *acpClient) ReleaseTerminal(context.Context, acp.ReleaseTerminalRequest) (acp.ReleaseTerminalResponse, error) {
	return acp.ReleaseTerminalResponse{}, errors.New("acp: terminal capability not enabled")
}
func (c *acpClient) WaitForTerminalExit(context.Context, acp.WaitForTerminalExitRequest) (acp.WaitForTerminalExitResponse, error) {
	return acp.WaitForTerminalExitResponse{}, errors.New("acp: terminal capability not enabled")
}
func (c *acpClient) KillTerminal(context.Context, acp.KillTerminalRequest) (acp.KillTerminalResponse, error) {
	return acp.KillTerminalResponse{}, errors.New("acp: terminal capability not enabled")
}

// filterEnv returns env with any KEY= entries matching the given
// prefixes removed. Used to strip CLAUDECODE and similar markers
// before spawning a child claude (avoids the nested-session error).
func filterEnv(env []string, drop ...string) []string {
	out := env[:0:0]
nextEntry:
	for _, e := range env {
		for _, d := range drop {
			if strings.HasPrefix(e, d+"=") {
				continue nextEntry
			}
		}
		out = append(out, e)
	}
	return out
}
