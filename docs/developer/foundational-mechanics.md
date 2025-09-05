# Foundational Mechanics for Claude Code Optimization

A comprehensive guide merging ClaudeLog's foundational mechanics for optimal Claude Code performance and contextual understanding.

## 1. You Are the Main Thread

### Core Principle
Think of yourself as a CPU scheduler. Every idle moment represents lost potential for parallel AI processing.

**Opportunity Cost Evolution**:
- Before AI: `opportunity cost × 1` (just your time)
- With AI: `(opportunity cost × 1) + (opportunity cost × N)` (your time + N parallel agents)

### Implementation
```bash
# Always spawn parallel processes
git status & git diff & git branch  # Run simultaneously
TodoWrite(task1) & Task(agent1) & Task(agent2)  # Parallel delegation
```

**Key Question**: "What asynchronous process could be running in the background delivering value?"

### Practical Application
- Queue tasks before starting
- Context switch efficiently between operations
- Never let your cognitive resources idle
- Treat your attention as the primary bottleneck

## 2. CLAUDE.md Supremacy

### Hierarchy Rules
1. **CLAUDE.md instructions** - Immutable system rules (highest priority)
2. **User prompts** - Flexible parameters within CLAUDE.md constraints

### Best Practices
```markdown
# CLAUDE.md Structure
## 1. Project Context [Immutable]
## 2. Architecture Rules [Immutable]
## 3. Workflow Processes [Sequential]
## 4. Code Style [Enforced]
## 5. Safety Constraints [Never Override]
```

### Strategic Approach
- **Tactically flood CLAUDE.md** with comprehensive context
- Break into modular functionality sections
- Use clear markdown boundaries
- Provide step-by-step workflows
- Include concrete examples

## 3. Plan Mode & Auto Plan Mode

### Manual Plan Mode
- **Activate**: Press `shift+tab` twice
- **Exit**: Press `shift+tab` again
- **Benefits**: No file edits without approval, structured suggestions

### Auto Plan Mode
Enable defensive workflows with system prompt:
```bash
claude code --append-system-prompt "Always enter Plan Mode for destructive operations"
```

### Usage Pattern
```markdown
Plan Mode Output:
1. Analysis of current state
2. Proposed changes (numbered)
3. Speed/complexity assessment
4. Risk evaluation
5. Approval required before execution
```

## 4. Always Be Experimenting (A.B.E)

### Mindset Shift
Engineers historically embrace new frameworks (jQuery, Bootstrap, CoffeeScript) but hesitate with AI. Break this pattern.

### Experimentation Framework
1. **Test boundaries** - Push Claude's capabilities daily
2. **Document findings** - Track what works/fails
3. **Share discoveries** - Contribute to community knowledge
4. **Iterate rapidly** - Quick feedback loops

### Practical Experiments
```bash
# Try parallel task variations
Task(debug) & Task(analyze) & Task(document)

# Test context limits
/context  # Monitor token usage
# Disable unused MCP tools when near limit

# Experiment with output styles
/output-style explanatory
/output-style:new custom_style
```

## 5. Context Engineering

### Context Inspection (`/context`)
Monitor token usage across:
- System Prompt
- System tools
- MCP tools
- Memory files
- Custom Agents
- Messages

### Context Window Constraints as Training
**Turn 200K token limit into skill development**:
- Curate context deliberately (don't dump entire codebases)
- Break tasks into context-sized chunks
- Structure code into lean modules
- Provide minimal, representative examples
- Write precise, targeted prompts

### Dynamic Memory Management
```bash
# Backup strategies
git stash  # Before context changes
cp CLAUDE.md CLAUDE.md.backup  # File duplication

# Memory refresh techniques
# reload context
# restart session
# explicit file reads
```

## 6. Poison Context Awareness

### Risk Prevention
Every piece of context can combine to create unintended behavior patterns.

### Vigilance Principles
1. **Scan for dangerous combinations** - Review context before adding
2. **Use explicit boundaries** - Separate distinct tasks clearly
3. **Clear context regularly** - Prevent accumulation of conflicting instructions
4. **Test incrementally** - Add context gradually, test behavior

### Implementation
```markdown
# CLAUDE.md Anti-Pattern Detection
## NEVER automatically deploy after code changes
## NEVER assume production environment
## ALWAYS require explicit confirmation for destructive operations
```

## 7. Output Styles & Permutation Frameworks

### Output Styles (`/output-style`)
Transform Claude's personality while maintaining tools:
- **Default**: Standard software engineering
- **Explanatory**: Educational insights between tasks
- **Learning**: Collaborative with TODO markers
- **Custom**: Create domain-specific styles

### Permutation Frameworks
Build repeatable patterns:
```markdown
# Feature Template in CLAUDE.md
## Component Creation Pattern
1. Always use this file structure
2. Include these imports
3. Follow this naming convention
4. Implement these interfaces
5. Add these tests
```

## 8. Sanity Checks & Validation

### Basic Sanity Check
```markdown
# CLAUDE.md
# My name is Frank
# Project: Fermi
# Branch: feature/email-verification
```

Test: "What's my name and current branch?"

### Advanced Validation Points
```markdown
# Checkpoint 1: Architecture validated ✓
# Checkpoint 2: Dependencies checked ✓
# Checkpoint 3: Tests passing ✓
```

## 9. Parallel Execution Patterns

### Task Batching
```bash
# Inefficient Sequential
Read file1 → Read file2 → Read file3 → Analyze

# Efficient Parallel
Read file1 & Read file2 & Read file3 → Analyze
```

### MCP Server Optimization
```bash
# Leverage specialized servers
--seq  # Complex debugging
--c7   # Framework documentation
--magic  # UI components
--morph  # Pattern-based edits

# Parallel MCP execution
Task(sequential-thinking) & Task(context7-docs) & Task(magic-ui)
```

## 10. Performance Optimization Techniques

### Token Efficiency Mode
When context >75%:
```markdown
# Symbol Communication
✅ Complete  ❌ Failed  ⚠️ Warning  🔄 Processing
→ leads to  ⇒ transforms  ∴ therefore  ∵ because

# Abbreviations
cfg=config impl=implementation arch=architecture
deps=dependencies val=validation opt=optimization
```

### Batch Operations
```bash
# Use MultiEdit over sequential Edits
MultiEdit(file, [edit1, edit2, edit3])

# Batch Read operations
Read([file1, file2, file3])

# Group related operations
git status && git diff && git log --oneline -5
```

## 11. Session Management Best Practices

### Session Lifecycle
```bash
# Start
list_memories() → read_memory("current_plan") → Resume

# During
write_memory("checkpoint", state) # Every 30min
TodoWrite → Track progress

# End
think_about_whether_done() → write_memory("summary", outcomes)
```

### Context Persistence
- Start sessions with: "Continue from X feature"
- Use TodoWrite for multi-step tracking
- Checkpoint regularly with memory writes
- Clear stale context when switching tasks

## 12. Anti-Patterns to Avoid

### Context Poisoning
❌ Mixing unrelated task contexts
❌ Accumulating conflicting instructions
❌ Leaving debug/test context in production flows

### Sequential Bottlenecks
❌ Running operations one-by-one
❌ Waiting for completion before starting next
❌ Not leveraging parallel MCP servers

### Token Waste
❌ Verbose explanations when not needed
❌ Repeating context unnecessarily
❌ Not using symbol communication when appropriate

## Quick Reference Card

### Essential Commands
```bash
/context           # Check token usage
/output-style      # Change personality
shift+tab (2x)     # Enter Plan Mode
/clear             # Clear context
TodoWrite          # Track tasks
Task --parallel    # Spawn parallel agents
```

### Parallel Patterns
```bash
# File Operations
Read(file1) & Read(file2) & Read(file3)

# Analysis
Task(debug) & Task(analyze) & Task(test)

# MCP Servers
--seq & --c7 & --magic

# Git Operations
git status & git diff & git branch
```

### Context Optimization
```bash
# When context >75%
--uc  # Ultra compressed
Disable unused MCP tools
Use symbol communication

# When context >85%
Essential operations only
Fail fast on complex requests
Clear and restart if needed
```

## Conclusion

The core philosophy: **Maximize parallel execution, minimize context waste, maintain clear boundaries**.

Remember:
- You are the main thread - delegate everything possible
- CLAUDE.md is law - user prompts are parameters
- Always be experimenting - push boundaries daily
- Context is precious - engineer it carefully
- Parallel > Sequential - always