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
  instance_type = "c5.xlarge"
  key_name      = aws_key_pair.marco_nix_key.key_name
  root_block_device {
    volume_size = 50
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

resource "aws_instance" "marco-storetheindex-indexer" {
  ami           = module.nixos_image_21_11.ami
  instance_type = "i3en.xlarge"
  key_name      = aws_key_pair.marco_nix_key.key_name

  security_groups = [aws_security_group.marco-storetheindex-sg.name]
  root_block_device {
    volume_size = 50
  }
}

resource "aws_instance" "marco-storetheindex-indexer-2" {
  ami           = module.nixos_image_21_11.ami
  instance_type = "i3en.xlarge"
  key_name      = aws_key_pair.marco_nix_key.key_name

  security_groups = [aws_security_group.marco-storetheindex-sg.name]
  root_block_device {
    volume_size = 50
  }
}

resource "aws_elb" "indexer-lb" {
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"]

  listener {
    instance_port     = 3000
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:3000/"
    interval            = 30
  }

  instances = [
    aws_instance.marco-storetheindex-indexer.id,
    aws_instance.marco-storetheindex-indexer-2.id
  ]

  tags = {
    Name = "loadtester-elb"
  }
}

resource "aws_cloudfront_distribution" "indexer_cloudfront" {
  enabled = true
  origin {
    domain_name = aws_elb.indexer-lb.dns_name
    origin_id   = "lb-${aws_elb.indexer-lb.id}"


    custom_origin_config {
      http_port              = 80
      origin_protocol_policy = "http-only"
      # Ignored, but still required
      https_port           = 443
      origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2", "SSLv3"]
    }
  }

  default_cache_behavior {
    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true
    forwarded_values {
      query_string = true
      cookies {
        forward = "all"
      }
    }

    target_origin_id       = "lb-${aws_elb.indexer-lb.id}"
    viewer_protocol_policy = "redirect-to-https"

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}



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

output "indexerIP" {
  value = aws_instance.marco-storetheindex-indexer.public_ip
}

output "indexer2IP" {
  value = aws_instance.marco-storetheindex-indexer-2.public_ip
}

output "deployerIP" {
  value = aws_instance.marco-storetheindex-deployer.public_ip
}
