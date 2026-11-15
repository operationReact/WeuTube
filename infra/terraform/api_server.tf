# Optional cost-controlled EC2 API host, enabled only by explicit Terraform variable.
variable "enable_api" { type = bool, default = false }
variable "api_instance_type" { type = string, default = "t3.medium" }
variable "api_hosted_zone_id" {
  description = "Existing Route53 hosted zone ID; when empty, create the DNS A record manually."
  type = string
  default = ""
}
locals { api_domain = "api.${var.domain_name}" }

data "aws_vpc" "api_default" { default = true }
data "aws_subnets" "api_default" {
  filter {
    name = "vpc-id"
    values = [data.aws_vpc.api_default.id]
  }
}
data "aws_ami" "api_al2023" {
  most_recent = true
  owners = ["amazon"]
  filter { name = "name", values = ["al2023-ami-2023.*-x86_64"] }
  filter { name = "architecture", values = ["x86_64"] }
}

resource "aws_security_group" "api" {
  count = var.enable_api ? 1 : 0
  name_prefix = "${local.prefix}-api-"
  vpc_id = data.aws_vpc.api_default.id
  ingress {
    description = "HTTP challenge and redirect"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_iam_role" "api" {
  count = var.enable_api ? 1 : 0
  name = "${local.prefix}-api-instance-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}
resource "aws_iam_role_policy_attachment" "api_ssm_manager" {
  count = var.enable_api ? 1 : 0
  role = aws_iam_role.api[0].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_role_policy_attachment" "api_youtube_secrets" {
  count = var.enable_api ? 1 : 0
  role = aws_iam_role.api[0].name
  policy_arn = aws_iam_policy.youtube_oauth_parameters.arn
}
resource "aws_iam_instance_profile" "api" {
  count = var.enable_api ? 1 : 0
  name = "${local.prefix}-api-profile"
  role = aws_iam_role.api[0].name
}

resource "aws_s3_bucket" "api_artifacts" {
  count = var.enable_api ? 1 : 0
  bucket_prefix = "${local.prefix}-api-artifacts-"
}
resource "aws_s3_bucket_public_access_block" "api_artifacts" {
  count = var.enable_api ? 1 : 0
  bucket = aws_s3_bucket.api_artifacts[0].id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_server_side_encryption_configuration" "api_artifacts" {
  count = var.enable_api ? 1 : 0
  bucket = aws_s3_bucket.api_artifacts[0].id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_iam_role_policy" "api_artifacts_read" {
  count = var.enable_api ? 1 : 0
  role = aws_iam_role.api[0].id
  name = "read-api-artifacts"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.api_artifacts[0].arn}/*"
    }]
  })
}

resource "aws_instance" "api" {
  count = var.enable_api ? 1 : 0
  ami = data.aws_ami.api_al2023.id
  instance_type = var.api_instance_type
  subnet_id = sort(data.aws_subnets.api_default.ids)[0]
  vpc_security_group_ids = [aws_security_group.api[0].id]
  iam_instance_profile = aws_iam_instance_profile.api[0].name
  user_data = file("${path.module}/bootstrap-api.sh")
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "required"
  }
  root_block_device {
    volume_size = 40
    volume_type = "gp3"
    encrypted = true
    delete_on_termination = false
  }
  tags = {
    Name = "${local.prefix}-api"
    Project = var.project
    Environment = var.environment
  }
}
resource "aws_eip" "api" {
  count = var.enable_api ? 1 : 0
  domain = "vpc"
  instance = aws_instance.api[0].id
}
resource "aws_route53_record" "api" {
  count = var.enable_api && var.api_hosted_zone_id != "" ? 1 : 0
  zone_id = var.api_hosted_zone_id
  name = local.api_domain
  type = "A"
  ttl = 60
  records = [aws_eip.api[0].public_ip]
}
output "api_domain" { value = var.enable_api ? local.api_domain : null }
output "api_eip" { value = var.enable_api ? aws_eip.api[0].public_ip : null }
output "api_instance_id" { value = var.enable_api ? aws_instance.api[0].id : null }
output "api_artifacts_bucket" { value = var.enable_api ? aws_s3_bucket.api_artifacts[0].id : null }
