provider "aws" {
        region = "us-east-2"
       
}
resource "aws_instance" "example" {
        ami = "ami-0b59bfac6be064b78"
        instance_type = "t2.micro"
        tags {
                Name = "git project"
        }
        key_name = "vasu"
        
}
