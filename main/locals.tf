locals {
  # 本番環境かどうか
  is_prod = terraform.workspace == "production"
  # VPCで利用するCIDRブロック
  cidr_block = local.is_prod ? "10.0.0.0/16" : "10.1.0.0/16"
  # TLS証明書のドメイン
  cert_domain = local.is_prod ? "example.com" : "staging.example.com"
}
