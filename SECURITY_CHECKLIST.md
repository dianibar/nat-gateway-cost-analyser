# Security Checklist

## Before Committing to Git

- [ ] No Terraform state files (*.tfstate)
- [ ] No Terraform variables file (terraform.tfvars)
- [ ] No AWS credentials files
- [ ] No API keys or tokens
- [ ] No SSH keys (*.pem, *.key)
- [ ] No environment files (.env)
- [ ] No secrets files

## Verify with Git

```bash
# Check what would be committed
git status

# Check for ignored files
git status --ignored

# Verify specific file is ignored
git check-ignore -v terraform/terraform.tfstate
git check-ignore -v terraform/terraform.tfvars
```

## Files That Should NEVER Be Committed

| File | Reason | Solution |
|------|--------|----------|
| `terraform.tfstate` | Contains infrastructure state | Use remote state (S3) |
| `terraform.tfstate.*` | State backups | Use remote state (S3) |
| `terraform.tfvars` | Contains API keys and secrets | Use `.tfvars.example` |
| `~/.aws/credentials` | AWS credentials | Store locally only |
| `.env` | Environment variables | Use `.env.example` |
| `*.pem` | SSH private keys | Store locally only |
| `secrets.json` | Secrets | Use AWS Secrets Manager |

## Files That SHOULD Be Committed

| File | Reason |
|------|--------|
| `terraform.tfvars.example` | Template for configuration |
| `.env.example` | Template for environment variables |
| `.gitignore` | Ignore patterns |
| `*.tf` | Terraform code |
| `*.sql` | SQL queries |
| `*.py` | Python code |
| `*.md` | Documentation |
| `requirements.txt` | Python dependencies |

## Pre-Commit Checks

```bash
# 1. Check for secrets
git diff --cached | grep -i "password\|secret\|key\|token\|api"

# 2. Check for state files
git diff --cached --name-only | grep -E "\.tfstate|\.tfvars|\.pem|\.key"

# 3. Check for credentials
git diff --cached | grep -E "aws_access_key|aws_secret_key|AKIA"

# 4. Check for environment files
git diff --cached --name-only | grep -E "\.env|\.credentials"
```

## If You Accidentally Committed Secrets

### Immediate Action

```bash
# 1. Remove from git (but keep locally)
git rm --cached terraform.tfvars
git commit -m "Remove terraform.tfvars from git"
git push

# 2. Rotate credentials
# - Generate new API keys
# - Update AWS credentials
# - Update DoitHub API key
```

### Remove from History (Advanced)

```bash
# WARNING: This rewrites git history!
# Only do this if you haven't pushed yet

git filter-branch --tree-filter 'rm -f terraform.tfvars' HEAD
git push --force-with-lease
```

## Configuration Files

### terraform.tfvars.example

```hcl
# Copy this file to terraform.tfvars and fill in your values
# DO NOT commit terraform.tfvars to git

aws_region   = "us-east-1"
cluster_name = "nat-gateway-analysis"

# DoitHub API Configuration
datahub_api_url          = "https://api.doit.com/datahub/v1/events"
datahub_api_key          = "your-api-key-here"
datahub_customer_context = "your-customer-context-here"
```

### .env.example

```bash
# Copy this file to .env and fill in your values
# DO NOT commit .env to git

AWS_REGION=us-east-1
AWS_PROFILE=default
DATAHUB_API_KEY=your-api-key-here
DATAHUB_CUSTOMER_CONTEXT=your-customer-context-here
```

## Secrets Management

### Option 1: AWS Secrets Manager (Recommended)

```bash
# Store secrets in AWS
aws secretsmanager create-secret \
  --name nat-gateway-analysis-datahub-api \
  --secret-string '{"api_key":"your-key","customer_context":"your-context"}'

# Retrieve in Lambda
secret = secrets_client.get_secret_value(SecretId='nat-gateway-analysis-datahub-api')
```

### Option 2: Environment Variables

```bash
# Set locally
export DATAHUB_API_KEY="your-api-key"
export DATAHUB_CUSTOMER_CONTEXT="your-context"

# Use in code
api_key = os.environ.get('DATAHUB_API_KEY')
```

### Option 3: .env File (Local Only)

```bash
# Create .env (never commit)
DATAHUB_API_KEY=your-api-key
DATAHUB_CUSTOMER_CONTEXT=your-context

# Load in code
from dotenv import load_dotenv
load_dotenv()
api_key = os.environ.get('DATAHUB_API_KEY')
```

## Team Collaboration

### Sharing Secrets Securely

1. **Use 1Password, LastPass, or similar**
   - Share credentials through password manager
   - Audit trail of who accessed what

2. **Use AWS Secrets Manager**
   - Centralized secret storage
   - IAM-based access control
   - Audit logging

3. **Use HashiCorp Vault**
   - Enterprise secret management
   - Dynamic secrets
   - Encryption and audit

### Never Share Via

- ❌ Email
- ❌ Slack/Teams
- ❌ Git commits
- ❌ Unencrypted files
- ❌ Shared documents

## Audit Trail

### Check Git History for Secrets

```bash
# Search for API keys in history
git log -p | grep -i "api_key\|secret\|password"

# Search for specific patterns
git log -p | grep -E "AKIA[0-9A-Z]{16}"

# Check all branches
git log -p --all | grep -i "secret"
```

### Remove from History

```bash
# Use git-filter-repo (recommended)
pip install git-filter-repo
git filter-repo --invert-paths --path terraform.tfvars

# Or use BFG Repo-Cleaner
bfg --delete-files terraform.tfvars
```

## Monitoring

### GitHub Secret Scanning

If using GitHub:
1. Enable secret scanning in repository settings
2. GitHub will alert if secrets are detected
3. Automatically revoke exposed tokens

### Pre-commit Hooks

```bash
# Install pre-commit framework
pip install pre-commit

# Create .pre-commit-config.yaml
cat > .pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
EOF

# Run before commit
pre-commit run --all-files
```

## Regular Reviews

### Weekly

- [ ] Check git log for accidental commits
- [ ] Verify .gitignore is working
- [ ] Review recent commits for secrets

### Monthly

- [ ] Rotate API keys
- [ ] Audit AWS credentials
- [ ] Review IAM permissions
- [ ] Check for exposed secrets

### Quarterly

- [ ] Security audit
- [ ] Update dependencies
- [ ] Review access logs
- [ ] Penetration testing

## Emergency Response

### If Credentials Are Exposed

1. **Immediate**
   - Revoke exposed credentials
   - Generate new credentials
   - Update all systems

2. **Short-term**
   - Remove from git history
   - Audit access logs
   - Check for unauthorized access

3. **Long-term**
   - Implement secret scanning
   - Add pre-commit hooks
   - Train team on security

## Resources

- [OWASP Secrets Management](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [git-filter-repo](https://github.com/newren/git-filter-repo)
