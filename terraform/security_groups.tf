# Security groups are kept deliberately separate and clearly named -- this is
# the piece later "broken scenarios" in this interview series will mutate
# (e.g. removing a rule, pointing a rule at the wrong SG) so keep each SG's
# purpose single and obvious.

# --- Cluster SG: attached to the EKS control plane's elastic network
# interfaces. Governs control-plane <-> node communication. ---
resource "aws_security_group" "cluster" {
  name        = "${var.project_name}-cluster-sg"
  description = "EKS control plane security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-cluster-sg"
  }
}

# --- Node SG: attached to the EKS worker node ENIs. ---
resource "aws_security_group" "nodes" {
  name        = "${var.project_name}-nodes-sg"
  description = "EKS worker node security group"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name                                          = "${var.project_name}-nodes-sg"
    "kubernetes.io/cluster/${local.cluster_name}" = "owned"
  }
}

# Nodes <-> nodes: all traffic between nodes in the same SG (pod-to-pod,
# kubelet, CNI plugin traffic).
resource "aws_security_group_rule" "nodes_ingress_self" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow nodes to communicate with each other on all ports"
}

# Control plane -> nodes: kubelet API (10250) and any port for webhooks/extension
# API servers.
resource "aws_security_group_rule" "nodes_ingress_cluster" {
  type                     = "ingress"
  from_port                = 1025
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow control plane to reach kubelet and node-hosted webhooks"
}

resource "aws_security_group_rule" "nodes_ingress_cluster_443" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes.id
  source_security_group_id = aws_security_group.cluster.id
  description              = "Allow control plane to reach node-hosted HTTPS webhooks (e.g. admission controllers)"
}

# Nodes -> control plane: kube-apiserver (443).
resource "aws_security_group_rule" "cluster_ingress_nodes" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster.id
  source_security_group_id = aws_security_group.nodes.id
  description              = "Allow worker nodes to reach the Kubernetes API server"
}

# Nodes: all outbound (ECR image pulls, AWS API calls via NAT, DNS, etc).
resource "aws_security_group_rule" "nodes_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.nodes.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from nodes"
}

# Cluster: all outbound (needed for the control plane to initiate connections
# to nodes/webhooks it doesn't already have explicit rules for).
resource "aws_security_group_rule" "cluster_egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.cluster.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow all outbound traffic from the control plane ENIs"
}
