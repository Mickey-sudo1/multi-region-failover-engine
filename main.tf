
# OPERATING SYSTEM LOOKUPS

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


# SSH KEYS


resource "aws_key_pair" "mumbai_key" {
  provider   = aws.primary
  key_name   = "engine-ssh-key"
  public_key = file("${path.module}/failover_key.pub")
}


resource "aws_key_pair" "singapore_key" {
  provider   = aws.backup
  key_name   = "engine-ssh-key"
  public_key = file("${path.module}/failover_key.pub")
}


# SECURITY GROUPS

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


# SERVERS - EC2

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


# AUTOMATED SCREEN OUTPUTS

output "mumbai_public_ip" {
  value = aws_instance.mumbai_server.public_ip
}

output "singapore_public_ip" {
  value = aws_instance.singapore_server.public_ip
}


# --- CLOUDFRONT ---

resource "aws_cloudfront_distribution" "failover_cdn" {
  enabled = true
  
  # Primary Server - Mumbai
  origin {
    domain_name = "ec2-3-110-77-117.ap-south-1.compute.amazonaws.com"
    origin_id   = "primary-mumbai"
    
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # We are using standard HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Backup Server - Singapore
  origin {
    domain_name = "ec2-13-212-20-230.ap-southeast-1.compute.amazonaws.com"
    origin_id   = "backup-singapore"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # The Traffic Cop: Origin Group
  origin_group {
    origin_id = "global-failover-group"

    failover_criteria {
      # If Mumbai throws any of these errors or times out, switch to Singapore
      status_codes = [403, 404, 500, 502, 503, 504]
    }

    member {
      origin_id = "primary-mumbai"
    }

    member {
      origin_id = "backup-singapore"
    }
  }

  # Routing Rules
  default_cache_behavior {
    target_origin_id       = "global-failover-group" # Point traffic to the GROUP, not a single server!
    viewer_protocol_policy = "allow-all"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# Output of the Free CloudFront URL when finished
output "global_failover_url" {
  value = aws_cloudfront_distribution.failover_cdn.domain_name
}