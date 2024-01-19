# ADOT Collector for EC2

This Helm Chart is a copy of the Chart by Bryan Aguilar from Amazon. This one only adds the posibility to set the security context
to the ADOT Collector Daemonset, as the collector fails to collect the PODs metrics if it does not run as the ROOT user. Check
the following links for more info.
* [EKS deployment template in the OTEL Collector Repo](https://github.com/aws-observability/aws-otel-collector/blob/main/deployment-template/eks/otel-container-insights-infra.yaml#L189-L191) - The template generated by AWS explicitly sets the security context to run the collector container as `root`.
* [GitHub comment](https://github.com/aws-observability/aws-otel-collector/issues/2486#issuecomment-1827642583) - Issue with Bottlerocket (AWS OS/Distro for running containers) that states that ADOT Collector is unable to retrieve Pods metrics, unless executed as `root`.