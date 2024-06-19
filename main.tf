provider "aws" {
  region = "ap-south-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  count = 3
  vpc_id = aws_vpc.main.id
  map_public_ip_on_launch = true

  availability_zone = element(["ap-south-1a", "ap-south-1b", "ap-south-1c"], count.index)
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)

  tags = {
    Name = "subnet-${count.index}"
  }
}

resource "aws_security_group" "eks" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-sg"
  }
}

resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "eks.amazonaws.com"
        },
        Effect = "Allow",
      },
    ],
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSServicePolicy",
  ]
}

resource "aws_iam_role" "eks_node" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
      },
    ],
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
  ]
}

resource "aws_eks_cluster" "k8s" {
  name = "my-cluster"
  role_arn = aws_iam_role.eks_cluster.arn

  vpc_config {
    subnet_ids = aws_subnet.subnet[*].id
  }
}

resource "aws_eks_node_group" "node_group" {
  cluster_name = aws_eks_cluster.k8s.name
  node_role_arn = aws_iam_role.eks_node.arn
  subnet_ids = aws_subnet.subnet[*].id

  scaling_config {
    desired_size = 3
    max_size = 3
    min_size = 1
  }
}

resource "aws_instance" "web" {
  ami = "ami-0e1d06225679bc1c5"
  instance_type = "t2.micro"
  subnet_id = element(aws_subnet.subnet[*].id, 0)

  tags = {
    Name = "web-server"
  }
}

