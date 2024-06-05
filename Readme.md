# SRE Assignment

This readme is intended to get you up and running with the cluster. The logic and reasoning is provided in the [SOLUTION.md]() file in more detail.

## Setup

You will need [SOPS](https://github.com/getsops/sops) as well as the `age-key.txt` file that should be put int the `secrets` directory.

Create an environment variable for SOPS that points to the age-key. This is required for decrypting the `secret.yaml` during deployment with Helm. 

From the projects root directory.
```
export SOPS_AGE_KEY_FILE=$(pwd)/secrets/age-key.txt
```

For Powershell users.
```
$ENV:SOPS_AGE_KEY_FILE="$($(pwd).Path)\secrets\age-key.txt"
```

You will also need the [helm-secrets](https://github.com/jkroepke/helm-secrets) plugin. Usually this can be installed with `helm plugin install https://github.com/jkroepke/helm-secrets` or if you get stuck you can visit the official docs [Here](https://github.com/jkroepke/helm-secrets/wiki/Installation)

For all the commands provided in the deployment section, I have also provided a Makefile for executing the same commands and deploying everything a little quicker. If you wish to use the Makefile, please ensure you update the context variable (CTX) before using the Makefile.

## Deployment

Lets start by creating our namespace where everything will live.

Create our namespace.
```
kubectl create namespace elastic-system
```

Using the Makefile.
```
make namespace
```

### Setup 

### Install CRDS

Eck-Elasticsearch uses a lot of custom resources and before we can deploy our chart we need to ensure these definitions exist on the cluster. These CRDs are provided by the `eck-operator-crds` chart.

All these commands should be ran from the `helm/eck-stack` directory.

Install CRDs.
```
helm upgrade elasticsearch charts/eck-operator-crds --install --atomic --cleanup-on-fail --namespace elastic-system
```

Using the Makefile.
```
make crds
```

### Deploy Chart

Once we have the CRDs added to the cluster we can deploy our Elasticsearch cluster and nodes. The following command will deploy the eck-operator which in turn will kick off the deployment of the statefulsets that contain our Elastic cluster.

Initial Install.
```
helm secrets upgrade elasticsearch ./ -f values.yaml -f secrets.yaml --install --atomic --cleanup-on-fail --namespace elastic-system
```

Using the Makefile
```
make elastic
```

From here the elastic operator will deploy. Once the operator has stabilized it will launch the deployment of the Elastic Search cluster. This usually takes a couple of minutes from initial deployment to completion.

If you want to use the Makefile and do everything in one go you can run.
```
make install
```

This should take care of creating a namespace, installing the CRDs and installing the Elasticsearch cluster.

## Obtaining Default Password

As part of the templates for deploying everything I included a user 'Filebeat' and assigned it a lot of different random roles. This account can also be used to log into Elastic. You can obtain the password via the secrets file with `sops secrets.yaml` which will load the file into your default editor.

If you want to obtain the default user account "elastic" password, you can run the following command.

```
kubectl get secret elastic-cluster-es-elastic-user -n elastic-system -o go-template='{{.data.elastic | base64decode}}'
```

If you found yourself on a Windows machine doing this somehow. You will not have 'base64decode' however you can use this one liner `[Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($kubectl_secret_hashed_output_value))` to decrypt a base64 value.

Or you can use the Makefile to do all this.
```
make get_elastic_user_pass
```
## First Login

With our deployment and credentials sorted. We can now access the Elastic API.

In a new terminal window, port forward the elastic-cluster service.
```
kubectl port-forward service/elastic-cluster-es-http 9200 --namespace elastic-system
```

You should then be able to curl the localhost 9200 port.
```
curl -u "elastic:$PASSWORD" -k "https://localhost:9200"
```

## Congrats

## Sources
* [Pretty much all of this. The official ECK docs.](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-overview.html)
* [ES User Setup to understand how to approach this.](https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-users-and-roles.html)
* [ES Node Roles](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-node.html)
* [Node Scheduling](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-advanced-node-scheduling.html)
* [Beats yaml file, simply helped me verify logs were being ingested.](https://github.com/elastic/beats/blob/main/deploy/kubernetes/filebeat-kubernetes.yaml)
* [Medium Article Tying a lot together. Also used as a functional example.](https://medium.com/@KushanJanith/run-elastic-stack-on-kubernetes-29e295cd6531)