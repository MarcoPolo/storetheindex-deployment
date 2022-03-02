module "nixos_image_21_11" {
  source  = "./aws_image_nixos"
  release = "21.11"
}

resource "aws_key_pair" "marco_nix_key" {
  key_name   = "marco_storetheindex_load_test_key"
  public_key = file("~/.ssh/marco-storetheindex-deployment.pub")
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
  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "marco-storetheindex-deployer" {
  ami             = module.nixos_image_21_11.ami
  instance_type   = "c5.xlarge"
  key_name        = aws_key_pair.marco_nix_key.key_name
  root_block_device {
    volume_size = 50
  }
  security_groups = [aws_security_group.marco-storetheindex-sg.name]
  user_data = <<-USEREOF
  {pkgs, modulesPath, ...}:
  {
    imports = [ "$${modulesPath}/virtualisation/amazon-image.nix" ];
    ec2.hvm = true;

    networking.hostName = "deployer";

    # Enable Flakes
    nix = {
      package = pkgs.nixFlakes;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };
  }
  USEREOF
}

output ip {
  value = aws_instance.marco-storetheindex-deployer.public_ip
}
