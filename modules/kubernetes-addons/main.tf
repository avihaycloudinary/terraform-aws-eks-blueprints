#-----------------AWS Managed EKS Add-ons----------------------

module "aws_vpc_cni" {
  count         = var.enable_amazon_eks_vpc_cni ? 1 : 0
  source        = "./aws-vpc-cni"
  addon_config  = var.amazon_eks_vpc_cni_config
  addon_context = local.addon_context
  enable_ipv6   = var.enable_ipv6
}

module "aws_coredns" {
  source = "./aws-coredns"

  count = var.enable_amazon_eks_coredns || var.enable_self_managed_coredns ? 1 : 0

  addon_context = local.addon_context

  # Amazon EKS CoreDNS addon
  enable_amazon_eks_coredns = var.enable_amazon_eks_coredns
  addon_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.amazon_eks_coredns_config,
  )

  # Self-managed CoreDNS addon via Helm chart
  enable_self_managed_coredns = var.enable_self_managed_coredns
  helm_config = merge(
    {
      kubernetes_version = local.eks_cluster_version
    },
    var.self_managed_coredns_helm_config,
    {
      # Putting after because we don't want users to overwrite this - internal use only
      image_registry = local.amazon_container_image_registry_uris[data.aws_region.current.name]
    }
  )
}

module "aws_kube_proxy" {
  count         = var.enable_amazon_eks_kube_proxy ? 1 : 0
  source        = "./aws-kube-proxy"
  addon_config  = var.amazon_eks_kube_proxy_config
  addon_context = local.addon_context
}

module "aws_ebs_csi_driver" {
  count         = var.enable_amazon_eks_aws_ebs_csi_driver ? 1 : 0
  source        = "./aws-ebs-csi-driver"
  addon_config  = var.amazon_eks_aws_ebs_csi_driver_config
  addon_context = local.addon_context
}

#-----------------Kubernetes Add-ons----------------------

module "agones" {
  count                        = var.enable_agones ? 1 : 0
  source                       = "./agones"
  helm_config                  = var.agones_helm_config
  eks_worker_security_group_id = var.eks_worker_security_group_id
  manage_via_gitops            = var.argocd_manage_add_ons
  addon_context                = local.addon_context
}

module "argocd" {
  count         = var.enable_argocd ? 1 : 0
  source        = "./argocd"
  helm_config   = var.argocd_helm_config
  applications  = var.argocd_applications
  addon_config  = { for k, v in local.argocd_addon_config : k => v if v != null }
  addon_context = local.addon_context
}

module "argo_rollouts" {
  count             = var.enable_argo_rollouts ? 1 : 0
  source            = "./argo-rollouts"
  helm_config       = var.argo_rollouts_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "aws_efs_csi_driver" {
  count             = var.enable_aws_efs_csi_driver ? 1 : 0
  source            = "./aws-efs-csi-driver"
  helm_config       = var.aws_efs_csi_driver_helm_config
  irsa_policies     = var.aws_efs_csi_driver_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "aws_fsx_csi_driver" {
  count             = var.enable_aws_fsx_csi_driver ? 1 : 0
  source            = "./aws-fsx-csi-driver"
  helm_config       = var.aws_fsx_csi_driver_helm_config
  irsa_policies     = var.aws_fsx_csi_driver_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "aws_for_fluent_bit" {
  count                    = var.enable_aws_for_fluentbit ? 1 : 0
  source                   = "./aws-for-fluentbit"
  helm_config              = var.aws_for_fluentbit_helm_config
  irsa_policies            = var.aws_for_fluentbit_irsa_policies
  cw_log_group_name        = var.aws_for_fluentbit_cw_log_group_name
  cw_log_group_retention   = var.aws_for_fluentbit_cw_log_group_retention
  cw_log_group_kms_key_arn = var.aws_for_fluentbit_cw_log_group_kms_key_arn
  manage_via_gitops        = var.argocd_manage_add_ons
  addon_context            = local.addon_context
}

module "aws_cloudwatch_metrics" {
  count             = var.enable_aws_cloudwatch_metrics ? 1 : 0
  source            = "./aws-cloudwatch-metrics"
  helm_config       = var.aws_cloudwatch_metrics_helm_config
  irsa_policies     = var.aws_cloudwatch_metrics_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "aws_load_balancer_controller" {
  count             = var.enable_aws_load_balancer_controller ? 1 : 0
  source            = "./aws-load-balancer-controller"
  helm_config       = var.aws_load_balancer_controller_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = merge(local.addon_context, { default_repository = local.amazon_container_image_registry_uris[data.aws_region.current.name] })
}

module "aws_node_termination_handler" {
  count                   = var.enable_aws_node_termination_handler && (length(var.auto_scaling_group_names) > 0 || var.enable_karpenter) ? 1 : 0
  source                  = "./aws-node-termination-handler"
  helm_config             = var.aws_node_termination_handler_helm_config
  irsa_policies           = var.aws_node_termination_handler_irsa_policies
  autoscaling_group_names = var.auto_scaling_group_names
  addon_context           = local.addon_context
}

module "cert_manager" {
  count                         = var.enable_cert_manager ? 1 : 0
  source                        = "./cert-manager"
  helm_config                   = var.cert_manager_helm_config
  manage_via_gitops             = var.argocd_manage_add_ons
  irsa_policies                 = var.cert_manager_irsa_policies
  addon_context                 = local.addon_context
  domain_names                  = var.cert_manager_domain_names
  install_letsencrypt_issuers   = var.cert_manager_install_letsencrypt_issuers
  letsencrypt_email             = var.cert_manager_letsencrypt_email
  allow_reuse_cert_after_delete = var.cert_manager_allow_reuse_cert_after_delete
}

module "cluster_autoscaler" {
  source = "./cluster-autoscaler"

  count = var.enable_cluster_autoscaler ? 1 : 0

  eks_cluster_version = local.eks_cluster_version
  helm_config         = var.cluster_autoscaler_helm_config
  manage_via_gitops   = var.argocd_manage_add_ons
  addon_context       = local.addon_context
}

module "coredns_autoscaler" {
  count             = var.enable_amazon_eks_coredns && var.enable_coredns_autoscaler && length(var.coredns_autoscaler_helm_config) > 0 ? 1 : 0
  source            = "./cluster-proportional-autoscaler"
  helm_config       = var.coredns_autoscaler_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "crossplane" {
  count            = var.enable_crossplane ? 1 : 0
  source           = "./crossplane"
  helm_config      = var.crossplane_helm_config
  aws_provider     = var.crossplane_aws_provider
  jet_aws_provider = var.crossplane_jet_aws_provider
  account_id       = data.aws_caller_identity.current.account_id
  aws_partition    = data.aws_partition.current.id
  addon_context    = local.addon_context
}

module "external_dns" {
  count             = var.enable_external_dns ? 1 : 0
  source            = "./external-dns"
  helm_config       = var.external_dns_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  irsa_policies     = var.external_dns_irsa_policies
  addon_context     = local.addon_context
  domain_name       = var.eks_cluster_domain
  private_zone      = var.external_dns_private_zone
}

module "fargate_fluentbit" {
  count         = var.enable_fargate_fluentbit ? 1 : 0
  source        = "./fargate-fluentbit"
  addon_config  = var.fargate_fluentbit_addon_config
  addon_context = local.addon_context
}

module "grafana" {
  count             = var.enable_grafana ? 1 : 0
  source            = "./grafana"
  helm_config       = var.grafana_helm_config
  irsa_policies     = var.grafana_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "ingress_nginx" {
  count             = var.enable_ingress_nginx ? 1 : 0
  source            = "./ingress-nginx"
  helm_config       = var.ingress_nginx_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "karpenter" {
  count                     = var.enable_karpenter ? 1 : 0
  source                    = "./karpenter"
  helm_config               = var.karpenter_helm_config
  irsa_policies             = var.karpenter_irsa_policies
  node_iam_instance_profile = var.karpenter_node_iam_instance_profile
  manage_via_gitops         = var.argocd_manage_add_ons
  addon_context             = local.addon_context
}

module "keda" {
  count             = var.enable_keda ? 1 : 0
  source            = "./keda"
  helm_config       = var.keda_helm_config
  irsa_policies     = var.keda_irsa_policies
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "kubernetes_dashboard" {
  count             = var.enable_kubernetes_dashboard ? 1 : 0
  source            = "./kubernetes-dashboard"
  helm_config       = var.kubernetes_dashboard_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "metrics_server" {
  count             = var.enable_metrics_server ? 1 : 0
  source            = "./metrics-server"
  helm_config       = var.metrics_server_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "ondat" {
  count             = var.enable_ondat ? 1 : 0
  source            = "ondat/ondat-addon/eksblueprints"
  version           = "0.1.1"
  helm_config       = var.ondat_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
  irsa_policies     = var.ondat_irsa_policies
  create_cluster    = var.ondat_create_cluster
  etcd_endpoints    = var.ondat_etcd_endpoints
  etcd_ca           = var.ondat_etcd_ca
  etcd_cert         = var.ondat_etcd_cert
  etcd_key          = var.ondat_etcd_key
  admin_username    = var.ondat_admin_username
  admin_password    = var.ondat_admin_password
}

module "kube_prometheus_stack" {
  count         = var.enable_kube_prometheus_stack ? 1 : 0
  source        = "./kube-prometheus-stack"
  helm_config   = var.kube_prometheus_stack_helm_config
  addon_context = local.addon_context
}

module "prometheus" {
  count       = var.enable_prometheus ? 1 : 0
  source      = "./prometheus"
  helm_config = var.prometheus_helm_config
  #AWS Managed Prometheus Workspace
  enable_amazon_prometheus             = var.enable_amazon_prometheus
  amazon_prometheus_workspace_endpoint = var.amazon_prometheus_workspace_endpoint
  manage_via_gitops                    = var.argocd_manage_add_ons
  addon_context                        = local.addon_context
}

module "spark_history_server" {
  count             = var.enable_spark_history_server ? 1 : 0
  source            = "./spark-history-server"
  helm_config       = var.spark_history_server_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
  irsa_policies     = var.spark_history_server_irsa_policies
  s3a_path          = var.spark_history_server_s3a_path
}

module "spark_k8s_operator" {
  count             = var.enable_spark_k8s_operator ? 1 : 0
  source            = "./spark-k8s-operator"
  helm_config       = var.spark_k8s_operator_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "tetrate_istio" {
  count                = var.enable_tetrate_istio ? 1 : 0
  source               = "tetratelabs/tetrate-istio-addon/eksblueprints"
  version              = "0.0.7"
  distribution         = var.tetrate_istio_distribution
  distribution_version = var.tetrate_istio_version
  install_base         = var.tetrate_istio_install_base
  install_cni          = var.tetrate_istio_install_cni
  install_istiod       = var.tetrate_istio_install_istiod
  install_gateway      = var.tetrate_istio_install_gateway
  base_helm_config     = var.tetrate_istio_base_helm_config
  cni_helm_config      = var.tetrate_istio_cni_helm_config
  istiod_helm_config   = var.tetrate_istio_istiod_helm_config
  gateway_helm_config  = var.tetrate_istio_gateway_helm_config
  manage_via_gitops    = var.argocd_manage_add_ons
  addon_context        = local.addon_context
}

module "traefik" {
  count             = var.enable_traefik ? 1 : 0
  source            = "./traefik"
  helm_config       = var.traefik_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "vault" {
  count = var.enable_vault ? 1 : 0

  # See https://registry.terraform.io/modules/hashicorp/hashicorp-vault-eks-addon/aws/
  source  = "hashicorp/hashicorp-vault-eks-addon/aws"
  version = "0.9.0"

  helm_config       = var.vault_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "vpa" {
  count             = var.enable_vpa ? 1 : 0
  source            = "./vpa"
  helm_config       = var.vpa_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "yunikorn" {
  count             = var.enable_yunikorn ? 1 : 0
  source            = "./yunikorn"
  helm_config       = var.yunikorn_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "csi_secrets_store_provider_aws" {
  count             = var.enable_secrets_store_csi_driver_provider_aws ? 1 : 0
  source            = "./csi-secrets-store-provider-aws"
  helm_config       = var.csi_secrets_store_provider_aws_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}

module "secrets_store_csi_driver" {
  count             = var.enable_secrets_store_csi_driver ? 1 : 0
  source            = "./secrets-store-csi-driver"
  helm_config       = var.secrets_store_csi_driver_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
}
module "aws_privateca_issuer" {
  count                   = var.enable_aws_privateca_issuer ? 1 : 0
  source                  = "./aws-privateca-issuer"
  helm_config             = var.aws_privateca_issuer_helm_config
  manage_via_gitops       = var.argocd_manage_add_ons
  addon_context           = local.addon_context
  aws_privateca_acmca_arn = var.aws_privateca_acmca_arn
  irsa_policies           = var.aws_privateca_issuer_irsa_policies
}

module "velero" {
  count             = var.enable_velero ? 1 : 0
  source            = "./velero"
  helm_config       = var.velero_helm_config
  manage_via_gitops = var.argocd_manage_add_ons
  addon_context     = local.addon_context
  irsa_policies     = var.velero_irsa_policies
  backup_s3_bucket  = var.velero_backup_s3_bucket
}

module "opentelemetry_operator" {
  source = "./opentelemetry-operator"

  count = var.enable_amazon_eks_adot || var.enable_opentelemetry_operator ? 1 : 0

  # Amazon EKS ADOT addon
  enable_amazon_eks_adot = var.enable_amazon_eks_adot
  addon_config = merge(
    {
      kubernetes_version = var.eks_cluster_version
    },
    var.amazon_eks_adot_config,
  )

  # Self-managed OpenTelemetry Operator via Helm chart
  enable_opentelemetry_operator = var.enable_opentelemetry_operator
  helm_config                   = var.opentelemetry_operator_helm_config

  addon_context = local.addon_context
}

module "adot_collector_java" {
  count  = var.enable_adot_collector_java ? 1 : 0
  source = "./adot-collector-java"

  helm_config   = var.adot_collector_java_helm_config
  addon_context = local.addon_context

  amazon_prometheus_workspace_endpoint = var.amazon_prometheus_workspace_endpoint
  amazon_prometheus_workspace_region   = var.amazon_prometheus_workspace_region

  depends_on = [
    module.opentelemetry_operator
  ]
}

module "adot_collector_haproxy" {
  count  = var.enable_adot_collector_haproxy ? 1 : 0
  source = "./adot-collector-haproxy"

  helm_config   = var.adot_collector_haproxy_helm_config
  addon_context = local.addon_context

  amazon_prometheus_workspace_endpoint = var.amazon_prometheus_workspace_endpoint
  amazon_prometheus_workspace_region   = var.amazon_prometheus_workspace_region

  depends_on = [
    module.opentelemetry_operator
  ]
}

module "adot_collector_memcached" {
  count  = var.enable_adot_collector_memcached ? 1 : 0
  source = "./adot-collector-memcached"

  helm_config   = var.adot_collector_memcached_helm_config
  addon_context = local.addon_context

  amazon_prometheus_workspace_endpoint = var.amazon_prometheus_workspace_endpoint
  amazon_prometheus_workspace_region   = var.amazon_prometheus_workspace_region

  depends_on = [
    module.opentelemetry_operator
  ]
}

module "adot_collector_nginx" {
  count  = var.enable_adot_collector_nginx ? 1 : 0
  source = "./adot-collector-nginx"

  helm_config   = var.adot_collector_nginx_helm_config
  addon_context = local.addon_context

  amazon_prometheus_workspace_endpoint = var.amazon_prometheus_workspace_endpoint
  amazon_prometheus_workspace_region   = var.amazon_prometheus_workspace_region

  depends_on = [
    module.opentelemetry_operator
  ]
}

module "external_secrets" {
  count         = var.enable_external_secrets ? 1 : 0
  source        = "./external-secrets"
  helm_config   = var.external_secrets_helm_config
  addon_context = local.addon_context
}
