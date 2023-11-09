# Sets AWS as provider and default region

# Gets latest Amazon Linux 2 AMI ID
# Gets list of available AZs in region
# Reads in user_data script file

# DEFINE RESOURCES
# - Create VPC and public subnets spread across AZs
# - Create internet gateway and public route table  
# - Create security groups for ALB and EC2 instances
# - Create application load balancer in public subnets
# - Create target group and listener for ALB
# - Create launch template and autoscaling group for EC2 instances
# - Attach ASG to ALB target group
# - Create WAF ACL with rules and associate to ALB
# - Create NACL to restrict ingress ports

# OUTPUTS 
# Print DNS name of load balancer

## PROVIDER

# define AWS provider
provider "aws" {
  region = var.region
}

## DATA SOURCES

# Data source: Get latest Amazon Linux 2 AMI ID
data "aws_ami" "amzlinux2" {
  most_recent = true

  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}


# Data source: query the list of AZs that are available
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source: Template file
data "template_file" "user_data" {
  template = file("${path.module}/user_data.sh")
}

locals {
  az_names = data.aws_availability_zones.available.names
}


## RESOURCES

# Declare VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

resource "aws_subnet" "public" {
  count                   = var.subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidrs[count.index]
  availability_zone       = local.az_names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "PublicSubnet${count.index}"
  }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route table with public route 
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate subnets with route table
resource "aws_route_table_association" "public" {
  count          = var.subnet_count
  subnet_id      = element(aws_subnet.public.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

# Create security group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "Allow web traffic to EC2 instances"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow web traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.ec2_ingress_cidrs
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.ec2_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create security group for ALB 
resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "Security group for application load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  ingress {
    description = "Allow HTTPS traffic"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.alb_ingress_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Create ALB
resource "aws_lb" "webserver" {
  name               = "webserver"
  internal           = false
  load_balancer_type = "application"
  subnets            = aws_subnet.public.*.id
  security_groups    = [aws_security_group.alb_sg.id]
}

# HTTP Listener for load balancer
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.webserver.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Attach EC2 to ALB target group 
resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

# Create launch template for web servers
resource "aws_launch_template" "web" {
  name          = "web-lt"
  instance_type = var.instance_type
  image_id      = data.aws_ami.amzlinux2.id
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ec2_sg.id]
  }

  user_data = base64encode(data.template_file.user_data.rendered)
}

# Create autoscaling group 
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  vpc_zone_identifier = aws_subnet.public.*.id
  health_check_type   = "ELB"

  desired_capacity = var.asg_desired_capacity
  max_size         = var.asg_max_size
  min_size         = var.asg_min_size

  target_group_arns = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }
}

# Attach ASG to load balancer
resource "aws_autoscaling_attachment" "web" {
  autoscaling_group_name = aws_autoscaling_group.web.id
  alb_target_group_arn   = aws_lb_target_group.web.arn
}

# Create WAF Web ACL
resource "aws_wafv2_web_acl" "ddos_protection" {
  name        = "ddos-protection"
  description = "Protects against DDoS"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "size-based-rule"
    priority = 1

    action {
      block {}
    }

    statement {
      size_constraint_statement {
        field_to_match {
          body {}
        }

        comparison_operator = "GT"
        size                = "10240"
        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "sizeRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "geo-match-rule"
    priority = 2

    action {
      block {}
    }

    statement {
      geo_match_statement {
        country_codes = var.geo_match_countries
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "geoMatchRuleMetrics"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "ddosProtectionMetrics"
    sampled_requests_enabled   = true
  }
}

# associate the web ACL w/ the ALB
resource "aws_wafv2_web_acl_association" "ddos_alb_assoc" {
  resource_arn = aws_lb.webserver.arn
  web_acl_arn  = aws_wafv2_web_acl.ddos_protection.arn
}

# Restrict ingress ports with NACL
resource "aws_network_acl" "web_nacl" {
  vpc_id = aws_vpc.main.id

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "-1"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  tags = {
    Name = "MainWebACL"
  }
}

## OUTPUTS

output "alb_dns_name" {
  value = aws_lb.webserver.dns_name
}
