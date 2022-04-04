data "aws_caller_identity" "current" {}

locals {
  prefix              = "marco"
  account_id          = data.aws_caller_identity.current.account_id
  ecr_repository_name = "${local.prefix}-storetheindex-read-load-gen-ecr"
  ecr_image_tag       = "latest"
}

module "nixos_image_21_11" {
  source  = "./aws_image_nixos"
  release = "21.11"
}

resource "aws_key_pair" "marco_nix_key" {
  key_name   = "marco_storetheindex_load_test_key"
  public_key = file(var.deploy_pub_key_path)
}

resource "aws_security_group" "marco-storetheindex-sg" {
  name = "nix_sg"
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 3000
    to_port   = 3003
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 2112
    to_port   = 2112
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
  }
  ingress {
    cidr_blocks = [
      "0.0.0.0/0"
    ]
    from_port = 9091
    to_port   = 9091
    protocol  = "tcp"
  }
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "marco-storetheindex-deployer" {
  ami           = module.nixos_image_21_11.ami
  instance_type = "c5.2xlarge"
  key_name      = aws_key_pair.marco_nix_key.key_name
  root_block_device {
    volume_size = 256
  }
  security_groups = [aws_security_group.marco-storetheindex-sg.name]
  user_data       = <<-USEREOF
  {pkgs, modulesPath, ...}:
  {
    imports = [ "$${modulesPath}/virtualisation/amazon-image.nix" ];
    ec2.hvm = true;

    networking.hostName = "deployer";
    networking.firewall.enable = false;

    # Enable Flakes
    nix = {
      package = pkgs.nixFlakes;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };
  }
  USEREOF

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.deploy_priv_key_path)
    host        = self.public_ip
  }


  provisioner "file" {
    source      = var.deploy_priv_key_path
    destination = "~/.ssh/id_ed25519"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 0600 ~/.ssh/id_ed25519",
      "nixos-rebuild switch",
    ]
  }
}

# resource "aws_instance" "marco-storetheindex-indexer" {
# ami           = module.nixos_image_21_11.ami
# instance_type = "i3en.xlarge"
# key_name      = aws_key_pair.marco_nix_key.key_name
#
# security_groups = [aws_security_group.marco-storetheindex-sg.name]
# root_block_device {
# volume_size = 50
# }
# }
#
# resource "aws_instance" "marco-storetheindex-indexer-2" {
# ami           = module.nixos_image_21_11.ami
# instance_type = "i3en.xlarge"
# key_name      = aws_key_pair.marco_nix_key.key_name
#
# security_groups = [aws_security_group.marco-storetheindex-sg.name]
# root_block_device {
# volume_size = 50
# }
# }
#
# resource "aws_elb" "indexer-lb" {
# availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]
#
# listener {
# instance_port     = 3000
# instance_protocol = "http"
# lb_port           = 80
# lb_protocol       = "http"
# }
#
# health_check {
# healthy_threshold   = 2
# unhealthy_threshold = 2
# timeout             = 3
# target              = "HTTP:3000/"
# interval            = 30
# }
#
# instances = [
# aws_instance.marco-storetheindex-indexer.id,
# aws_instance.marco-storetheindex-indexer-2.id
# ]
#
# tags = {
# Name = "loadtester-elb"
# }
# }
#
# resource "aws_cloudfront_distribution" "indexer_cloudfront" {
# enabled = true
# origin {
# domain_name = aws_elb.indexer-lb.dns_name
# origin_id   = "lb-${aws_elb.indexer-lb.id}"
#
#
# custom_origin_config {
# http_port              = 80
# origin_protocol_policy = "http-only"
# # Ignored, but still required
# https_port           = 443
# origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
# }
# }
#
# default_cache_behavior {
# allowed_methods = ["GET", "HEAD"]
# cached_methods  = ["GET", "HEAD"]
# compress        = true
# forwarded_values {
# query_string = true
# cookies {
# forward = "all"
# }
# }
#
# target_origin_id       = "lb-${aws_elb.indexer-lb.id}"
# viewer_protocol_policy = "redirect-to-https"
#
# min_ttl     = 0
# default_ttl = 3600
# max_ttl     = 86400
#
# }
#
# custom_error_response {
# error_code            = 404
# error_caching_min_ttl = 300
# }
#
# aliases = ["storetheindex.marcopolo.io"]
# viewer_certificate {
# acm_certificate_arn = "arn:aws:acm:us-east-1:407967248065:certificate/d3bc970e-823e-4e44-934b-928e21267c52"
# ssl_support_method  = "sni-only"
# }
#
# restrictions {
# geo_restriction {
# restriction_type = "none"
# }
# }
# }




# resource "aws_instance" "gammazero-storetheindex-indexer" {
#   ami           = module.nixos_image_21_11.ami
#   instance_type = "i3en.xlarge"
#   key_name      = aws_key_pair.marco_nix_key.key_name

#   security_groups = [aws_security_group.marco-storetheindex-sg.name]
#   root_block_device {
#     volume_size = 50
#   }
# }

# output "gammazeroIndexerIP" {
#   value = aws_instance.gammazero-storetheindex-indexer.public_ip
# }

resource "aws_ecr_repository" "storetheindex-read-load-gen" {
  name = local.ecr_repository_name
}

resource "aws_iam_role" "iam_for_storetheindex_read_load_gen_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "null_resource" "deploy_deployer_config" {
  # Depends on the deployer running since the deployer builds the container
  depends_on = [
    aws_instance.marco-storetheindex-deployer
  ]

  triggers = {
    deployer_ip = aws_instance.marco-storetheindex-deployer.public_ip
  }

  # Switch the deployer to the defined NixOS Config
  provisioner "local-exec" {
    command = <<EOF
          nix run . -- .#deployer
       EOF
  }
}

resource "null_resource" "read_load_gen_ecr_image" {
  # Depends on the deployer running since the deployer builds the container
  depends_on = [
    null_resource.deploy_deployer_config
  ]

  triggers = {
    file_hashes = jsonencode({
      for f in fileset("${path.module}/load-testing-tools/read-load-generator", "**") :
      f => filesha256("${path.module}/load-testing-tools/read-load-generator/${f}")
    })
  }

  provisioner "local-exec" {
    command = <<EOF
           aws ecr get-login-password --region ${var.region} --profile ${var.profile} | docker login --username AWS --password-stdin ${local.account_id}.dkr.ecr.${var.region}.amazonaws.com
           nix run .#build-and-fetch-load-gen-container
           docker tag storetheindex-read-load-gen:latest ${aws_ecr_repository.storetheindex-read-load-gen.repository_url}:latest
           docker push ${aws_ecr_repository.storetheindex-read-load-gen.repository_url}:latest
       EOF
  }
}

data "aws_ecr_image" "read_load_gen_container_image" {
  depends_on = [
    null_resource.read_load_gen_ecr_image
  ]
  repository_name = local.ecr_repository_name
  image_tag       = local.ecr_image_tag
}

resource "aws_lambda_function" "storetheindex_read_load_gen_lambda" {
  function_name = "storetheindex_read_load_gen_lambda"
  role          = aws_iam_role.iam_for_storetheindex_read_load_gen_lambda.arn
  architectures = ["arm64"]

  image_uri    = "${aws_ecr_repository.storetheindex-read-load-gen.repository_url}@${data.aws_ecr_image.read_load_gen_container_image.id}"
  package_type = "Image"
  timeout      = 60 * 10
  memory_size  = 512
}

output "storetheindex-read-load-gen-repo" {
  value = aws_ecr_repository.storetheindex-read-load-gen.repository_url
}

output "read-load-gen-lambda-arn" {
  value = aws_lambda_function.storetheindex_read_load_gen_lambda.arn
}

# output "indexerIP" {
#   value = aws_instance.marco-storetheindex-indexer.public_ip
# }
#
# output "indexer2IP" {
#   value = aws_instance.marco-storetheindex-indexer-2.public_ip
# }

output "deployerIP" {
  value = aws_instance.marco-storetheindex-deployer.public_ip
}

# output "cloudfrontURL" {
#   value = aws_cloudfront_distribution.indexer_cloudfront.domain_name
# }
