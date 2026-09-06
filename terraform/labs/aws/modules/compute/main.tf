resource "aws_instance" "this" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = var.security_group_ids
  iam_instance_profile = var.iam_instance_profile
  associate_public_ip_address = true
  key_name                    = var.key_name

  credit_specification {
    cpu_credits = "standard"
  }

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = var.instance_name
  }
}
