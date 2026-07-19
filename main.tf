# ==========================================
# 1. DYNAMIC OPERATING SYSTEM LOOKUPS
# ==========================================
data "aws_ami" "ubuntu_mumbai" {
  provider    = aws.primary
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_ami" "ubuntu_singapore" {
  provider    = aws.backup
  most_recent = true
  owners      = ["099720109477"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ==========================================
# 2. CRYPTOGRAPHIC SSH KEYS
# ==========================================
# This reads your local .pub file and uploads it as a lock to Mumbai
resource "aws_key_pair" "mumbai_key" {
  provider   = aws.primary
  key_name   = "engine-ssh-key"
  public_key = file("${path.module}/failover_key.pub")
}

# This uploads the exact same lock to Singapore
resource "aws_key_pair" "singapore_key" {
  provider   = aws.backup
  key_name   = "engine-ssh-key"
  public_key = file("${path.module}/failover_key.pub")
}

# ==========================================
# 3. VIRTUAL FIREWALLS (SECURITY GROUPS)
# ==========================================
resource "aws_security_group" "mumbai_sg" {
  provider    = aws.primary
  name        = "failover-engine-sg"
  description = "Allow inbound SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "singapore_sg" {
  provider    = aws.backup
  name        = "failover-engine-sg"
  description = "Allow inbound SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# 4. VIRTUAL SERVERS (EC2 INSTANCES)
# ==========================================
resource "aws_instance" "mumbai_server" {
  provider               = aws.primary
  ami                    = data.aws_ami.ubuntu_mumbai.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.mumbai_sg.id]
  key_name               = aws_key_pair.mumbai_key.key_name # Attaches the lock!
  
  tags = {
    Name = "Primary-Mumbai-Server"
  }
}

resource "aws_instance" "singapore_server" {
  provider               = aws.backup
  ami                    = data.aws_ami.ubuntu_singapore.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [aws_security_group.singapore_sg.id]
  key_name               = aws_key_pair.singapore_key.key_name # Attaches the lock!

  tags = {
    Name = "Backup-Singapore-Server"
  }
}

# ==========================================
# 5. AUTOMATED SCREEN OUTPUTS
# ==========================================
output "mumbai_public_ip" {
  value = aws_instance.mumbai_server.public_ip
}

output "singapore_public_ip" {
  value = aws_instance.singapore_server.public_ip
}