module "nixos_image_21_11" {
  source  = "./aws_image_nixos"
  release = "21.11"
}

resource "aws_key_pair" "nix_key" {
  key_name   = "marco_mukta_key"
  public_key = file("~/.ssh/id_ed25519.pub")
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
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "marco-storetheindex" {
  ami             = module.nixos_image_21_11.ami
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.nix_key.key_name
  security_groups = [aws_security_group.marco-storetheindex-sg.name]
}

output ip {
  value = aws_instance.marco-storetheindex.public_ip
}
