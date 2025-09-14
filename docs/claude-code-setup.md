# Claude Code GitHub Actions Setup Guide

## Overview
This document provides instructions for setting up Claude Code v1.0 GitHub Actions in the Fermi Flutter project.

## Required GitHub Secrets

### 1. ANTHROPIC_API_KEY (Required)
This is your Anthropic API key for Claude Code authentication.

**To obtain:**
1. Sign up for an Anthropic account at https://console.anthropic.com
2. Navigate to API Keys section
3. Create a new API key or use an existing one
4. Copy the key (starts with `sk-ant-api...`)

**To add to GitHub:**
1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret"
4. Name: `ANTHROPIC_API_KEY`
5. Value: Your API key from Anthropic Console
6. Click "Add secret"

### 2. CLAUDE_CODE_OAUTH_TOKEN (Optional)
Enhanced GitHub integration token for better code context understanding.

**To obtain:**
1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Click "Generate new token (classic)"
3. Give it a descriptive name like "Claude Code Integration"
4. Select scopes:
   - `repo` (Full control of private repositories)
   - `read:org` (Read org and team membership)
   - `read:user` (Read user profile data)
5. Generate and copy the token

**To add to GitHub:**
1. Follow the same steps as above
2. Name: `CLAUDE_CODE_OAUTH_TOKEN`
3. Value: Your GitHub personal access token

## Workflow Configuration

### Claude Code Review Workflow
Location: `.github/workflows/claude-code-review.yml`

**Triggers:**
- Pull requests to master branch (opened, synchronize, reopened)
- Manual workflow dispatch with optional PR number

**Features:**
- Flutter-specific code review
- Firebase security analysis
- Architecture and design pattern validation
- Performance optimization suggestions
- MCP servers: context7 and sequential-thinking

### CI Pipeline Enhancement
Location: `.github/workflows/01_ci.yml`

**New Job:** `claude-architecture-analysis`
- Runs after validation job
- Analyzes architecture and technical debt
- Provides improvement recommendations
- Runs only on pull requests

## MCP Server Configuration

### Context7 Server
Provides curated Flutter/Dart documentation and patterns.

**Configuration:**
```json
{
  "command": "npx",
  "args": ["@context7/mcp-server", "start"],
  "includeTools": [
    "flutter_architecture",
    "dart_best_practices",
    "firebase_flutter",
    "provider_state_management"
  ]
}
```

### Sequential-Thinking Server
Enables complex architectural reasoning and analysis.

**Configuration:**
```json
{
  "command": "npx",
  "args": ["@sequential-thinking/mcp-server", "start"],
  "env": {
    "MAX_THINKING_STEPS": "20",
    "ANALYSIS_DEPTH": "deep"
  }
}
```

## Testing the Configuration

### 1. Verify Secrets
```bash
# Check if secrets are configured (in GitHub Actions run)
echo "API Key configured: ${{ secrets.ANTHROPIC_API_KEY != '' }}"
```

### 2. Manual Workflow Test
1. Go to Actions tab in GitHub
2. Select "Claude Code Review" workflow
3. Click "Run workflow"
4. Optionally enter a PR number
5. Monitor the execution

### 3. Pull Request Test
1. Create a test PR with minor changes
2. Watch for Claude Code Review to run automatically
3. Check PR comments for Claude's analysis

## Monitoring and Logs

### View Workflow Runs
1. Navigate to Actions tab
2. Select specific workflow run
3. Click on job to see detailed logs

### Common Issues

**Issue:** Workflow fails with authentication error
**Solution:** Verify ANTHROPIC_API_KEY is correctly set in repository secrets

**Issue:** MCP servers fail to start
**Solution:** Check network connectivity and npm package availability

**Issue:** No PR comments appear
**Solution:** Ensure workflow has pull-requests: write permission

## Cost Considerations

- Claude Code uses Anthropic API tokens
- Each PR review typically uses 5,000-10,000 tokens
- Architecture analysis uses 3,000-6,000 tokens
- Monitor usage in Anthropic Console

## Coexistence with Gemini Workflows

Both Claude Code and Gemini workflows can run simultaneously:
- **Gemini:** Fast triage and general reviews
- **Claude Code:** Deep architectural analysis and Flutter-specific insights

## Support

For issues or questions:
- Claude Code Action: https://github.com/anthropics/claude-code-action/issues
- Anthropic Support: https://support.anthropic.com
- Project Issues: Create an issue in this repository