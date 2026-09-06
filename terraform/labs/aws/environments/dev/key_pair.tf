resource "aws_key_pair" "dev" {
  key_name   = var.key_name
  public_key = file("/home/vagrant/.ssh/expense-tracker-dev.pub")

  tags = {
    Name = var.key_name
  }
}
