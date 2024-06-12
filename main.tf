# YOU NEED VAULT_ADDR, VAULT_NAMESPACE, VAULT_TOKEN
data "external" "env" {
  program = ["${path.module}/env.sh"]
}

locals {
  vault_address   = data.external.env.result["address"]
  vault_namespace = data.external.env.result["namespace"]
  vault_token     = data.external.env.result["token"]
  vault_oidc_path = "cognito"
  aws_region      = "ap-northeast-2"
}

provider "aws" {
  region = local.aws_region
}

provider "vault" {
  address   = local.vault_address
  namespace = local.vault_namespace
}

#######################################
### AWS Cognito
#######################################

resource "aws_cognito_user_pool" "vault" {
  name = "vault"
}

resource "aws_cognito_user_pool_client" "vault" {
  name            = "vault-client"
  user_pool_id    = aws_cognito_user_pool.vault.id
  generate_secret = true

  allowed_oauth_flows                  = ["code", "implicit"]
  allowed_oauth_scopes                 = ["email", "openid"]
  allowed_oauth_flows_user_pool_client = true

  supported_identity_providers = ["COGNITO"]

  callback_urls = [
    "http://localhost:8250/oidc/callback",
    "${local.vault_address}/ui/vault/auth/${local.vault_oidc_path}/oidc/callback",
  ]
}

resource "aws_cognito_user_pool_domain" "vault" {
  domain       = "vault-domain"
  user_pool_id = aws_cognito_user_pool.vault.id
}

resource "aws_cognito_user" "vault_user" {
  user_pool_id = aws_cognito_user_pool.vault.id
  username     = "example_user"
  attributes = {
    email = "example_user@example.com"
  }
  password = "StaticPassword123!"
  // temporary_password = "TempPassword123!"
}

#######################################
### Vault OIDC
#######################################

resource "vault_jwt_auth_backend" "cognito" {
  path               = local.vault_oidc_path
  type               = "oidc"
  default_role       = "default"
  oidc_discovery_url = "https://cognito-idp.${local.aws_region}.amazonaws.com/${aws_cognito_user_pool.vault.id}"
  oidc_client_id     = aws_cognito_user_pool_client.vault.id
  oidc_client_secret = aws_cognito_user_pool_client.vault.client_secret

  lifecycle {
    ignore_changes = [oidc_client_secret]
  }
}

resource "vault_policy" "admin_cognito" {
  name = "admin-cognito"

  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}

resource "vault_jwt_auth_backend_role" "admin" {
  backend        = vault_jwt_auth_backend.cognito.path
  role_name      = "default"
  token_ttl      = 3600
  token_max_ttl  = 3600
  token_policies = [vault_policy.admin_cognito.name]

  bound_audiences = [aws_cognito_user_pool_client.vault.id]
  user_claim      = "sub"
  claim_mappings = {
    preferred_username = "username"
    email              = "email"
  }
  role_type = "oidc"
  allowed_redirect_uris = [
    "http://localhost:8250/oidc/callback",
    "${local.vault_address}/ui/vault/auth/${local.vault_oidc_path}/oidc/callback",
    "https://${aws_cognito_user_pool_domain.vault.domain}.auth.${local.aws_region}.amazoncognito.com"
  ]
}

