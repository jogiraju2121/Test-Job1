resource "aws_instance" "example" {
        ami = "ami-0b59bfac6be064b78"
        instance_type = "t2.micro"
        tags {
                Name = "terraform-example"
        }
        key_name = "vasu"
        
}
