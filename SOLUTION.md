## Why this method to deploy helm charts?

Specifically the Elasticsearch chart, honestly threw me a curve. We currently deploy our Elasticsearch clusters via Terraform and Elastic Cloud so I needed a quick crash course in the eck-elastic charts. The eck-elastic chart is built purely from elastic CRDs and that took me longer to realize than I want to admit (casually overlooking kind: elasticsearch). This created a small delay in that I was exploring ways of deploying Elasticsearch, It wasn't until after reading through a medium article I realized the CRDs and checked the eck-elasticsearch chart again and everything clicked for me. 

I had created `elastic-search.yaml` before I noticed the chart in the repo elastic/eck-elasticsearch was practically the same thing. After doing a quick compare of the two I noticed my template file was pretty much the same as the upstream repo version. Minus a few configuration details here and there. I decided to leave my template since it was 'close enough' and I can pass it off as a "See I can helm template" excuse. I felt like leaving it also as more of a lesson learned and a walk-through of the process. Also rewriting the chart helped me understand how everything is deployed a bit better.

If I was to do this differently or start-over. After learning the ECK charts, and going over the documentation. I'd go back to my original way of working with helm charts. Cloning each chart required for a deployment into the charts directory and writing my own values.yaml to overlay on the eck-elasticsearch chart. Doing it this way means a custom template does not have to be maintained to ensure its consistent with the upstream charts. This primarily helps with ensuring the chart can be updated with dependency management tools, or if you deploy charts in ArgoCD using the 'Chart.yaml' file for dependencies.

The only chart that was more 'traditional' and uses the method of how I would normally deploy charts is the `eck-operator` and CRDs chart for it. The way I normally deploy charts is reflected by the deployment of the eck-operator and its CRDs.

I prefer packaging the full charts used in deployment with the codebase it will live in. This reduces the dependency on 3rd party repositories and ensures the base chart is available to everyone working on it who has the codebase.

## Strategy 

* I noticed there were 3 nodes in the provided cluster.
    * 3 ES nodes with 3 pods spread across 3 k8s nodes.
            * This just covers availability and helps with Elastic replication at the index level.
            * Resources can be split in 3rds.
            * Any given node can be offline but elastic data will still be available.
    * Setting a `podAntiAffinity` annotation based on ES cluster name to ensure pods for each ES node are spread across all three k8s nodes evenly. Node1 will always attempt to keep its pods away from each other for example.
        * Given more time, I might consider making each es node have a unique label for antiaffinity rules.
        * Current label of elastic-cluster is fine enough
        * Other projects I might split the label by node.roles or something more unique.
    * Set `minAvailable` pods to 1 to ensure the ES nodes are always available. If I recall correctly, this is also the default behaviour so not configured via values.
    * For an initial deployment I split the resources of the k8s nodes into 3rds minus some overhead and the operator.
    * I've not carved out a ton of storage space on purpose however I've provided a value to adjust everything with.I also provide a value for the type of storage class since you might want different types if you split ES nodes between hot/warm/cold or use different backends.
        * I have set the storageclass as gp2 since that is what is provided.

### Handling Upgrades

I wont reinvent the wheel here. 

As long as Pod disruption budget is set, you have enough ES and k8s nodes spread across all your resources. It should be safe to follow the official documentation.
* Implement PDB https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-pod-disruption-budget.html at the ES node level.
* Roll out HPA if its a requirement for the project. [docs](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-autoscaling.html). This might not be needed with this deployment since everything is split evenly and right sized based on a rules of thirds.
* Ensure indices contain replicas since this helps with rolling upgrades and ensures data is not isolated to a single ES node.
* https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-upgrading-stack.html
* https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-update-strategy.html
* https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-orchestration.html


### Monitoring

* I'd roll out a chart for Prometheus called '[Prometheus Elasticsearch exporter](https://github.com/prometheus-community/elasticsearch_exporter)'
    * Setup cluster health checks. We've found this metric can help catch over sharding and issues with indexing.
        * Expression: `elasticsearch_cluster_health_status{color='yellow'} > 0` for 10 minutes
        * Expression: `elasticsearch_cluster_health_status{color='red'} > 0` for 2 minutes
    * I've also found a nice Grafana dashboard for use with this tool [Dashboard](https://grafana.com/grafana/dashboards/14191-elasticsearch-overview/).
        * From here you can take the queries for for dashboards and build out Alerts after setting a baseline for use.
        * Things to look for are over Shard health, index size and rate and queue count.
            * elasticsearch_cluster_health_initializing_shards (values based on this specific clusters behaviour)
            * elasticsearch_cluster_health_number_of_nodes (should align with your setup)
            * elasticsearch_thread_pool_queue_count (values based on specific clusters behaviour)
    * I've also enabled Prometheus metrics on the eck-operator.
    * It might also be useful to monitor K8S node usage as well as PVC usage and inode usage.

## Sensitive Stuff

Why choose SOPS and why choose the Age method?

* I learned to use SOPS initially when setting up encrypted yaml/json secrets and its always been reliable and easy enough to use.
* I use AGE for personal/private projects since it doesn't require a Key management system.
* For enterprise or actual large projects I'd go the KMS route for encryption. We currently use Google Key Management System since our IAM permissions can be scoped to keys that enables certain teams to encrypt/decrypt certain files depending on the key used to sign them.

* I decided to deploy 1 account with this setup.
    * Good practice to provide accounts and save master accounts for admin purposes and use SAML or SSO for daily work.
    * Mostly to show how to add accounts with roles via helm and secrets.
    * Displaying how I use SOPS and how it can be used within projects.
    * Why not create a secrets resource and reference that?
        * Some values are quicker to fill in and encrypt the file.
            * You wouldn't do this for very sensitive values. Some webhooks come to mind.
            * You wouldn't use it for any value that would be generated in clear-text with `helm template`.
                * To best secure credentials its best to create a k8s secret resource and reference this in your chart where the value is needed.

## Improvements
* Since this project would live in repository, I'd first setup some dependency management configuration with dependabot or renovate. The primary purpose for this repository is just for Helm chart updates.
* Add deployed Kubernetes resources to some type of backup tooling like Velero.
* If there is a common authentication mechanism I'd explore SAML via the elastic config file or SSO at the service level on Kubernetes with something like [oauth2-proxy](https://github.com/oauth2-proxy/oauth2-proxy).
* Spread storage across Cloud availability zones.
    * In GCP we would use europe-west4 which is Amsterdam for primary use.
    * We would also use something like europe-west3 in Frankfurt.
    * If the project used hot/warm/cold nodes you might configure appropriate storage tier.
    * The strategy would be business lead since it does incur costs and require extra complexity. Some projects might not need it, others might.
* Use the correct elast/eck-elasticsearch chart vs my own template. 
* Write an application and/or project template for ArgoCD to put this tooling into if available.
* I didn't do anything with certificates and services since I would have to infer a few things and don't think it was the scope of the assignment. I would like to just cover what I would do.
    * Everywhere I've been, we lean into Cert-manager with Lets Encrypt. Removing the overhead of certificates when going through a provider like Cloudflare.
    * If the Cert-manager option is not around, I know its possible to generate and store certificates in k8s. Then you can reference these secrets elsewhere to be used. Again, I know its possible, but I've never had to do it because cert-manager is such a no brainer vs self signed certificates.
* Every time I go near my `templates\elastic-search.yaml` file I want to adjust it with every new bit of knowledge I gain from ECK.
* Maybe helm chart tests but due to the requirements and size of this project, they might not be 100% needed.

## Random Things

* I just needed to stop at a certain point as I was getting to caught up in the documentation side. Essentially overthinking and trying to cover as many bases as possible.
* I had a laugh when receiving the assignment. This is the one service we do not host in k8s at my current place so you managed to find something totally out of my knowledge scope and comfort zone 👏.  We do everything via Elasticcloud because of everything I went through working on this assignment gets offloaded to them and their support teams.
* I didn't want to use some method I'm not familiar with for deploying charts like Kustomize or similar.
* Everything was built and 'tested' in my homelab using k3s. I deployed to the provided cluster once I reached a point I was comfortable with to ensure it worked there.
* If you turn off filebeat, add template/secrets.yaml to .helmignore and remove the 'secret' after helm secrets as -f secrets.yaml. You can still deploy the cluster without needing the encryption. Its mostly there to demo adding a new user with roles.
* I throw the k8s context into every command simply because its safer. A lot of the initial way of working we used deployment scripts or Makefiles that did not have a context defined and it made for some fun accidental deployments into the wrong clusters. Fortunately we use a policy management tool like Kyverno and our environment label did not match the cluster so it prevents the deployment. Better safe than sorry however.
* I didn't have my Mac laptop working, didn't want to use my work Laptop for this and didn't have a Linux VM ready for k8s work. So everything was done on a windows desktop. I've attempted to explain nuances when they pop up.
* I had fun with this. So thanks!
