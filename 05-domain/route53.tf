# domain/route53.tf

data "aws_route53_zone" "main" {
  name         = "neves-box.com"
  private_zone = false
}

data "aws_lb" "ingress_alb" {
  tags = {
    "ingress.k8s.aws/stack"   = "neves/main-ingress" # <namespace>/<ingress-name>
  }
}

resource "aws_route53_record" "subdomain" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.neves-box.com"
  type    = "A"

  alias {
    name                   = data.aws_lb.ingress_alb.dns_name
    zone_id                = data.aws_lb.ingress_alb.zone_id
    evaluate_target_health = true
  }
}
