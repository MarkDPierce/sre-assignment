# My standard make file for deploying and working with helm charts on clusters.
#
# There is a small quirk to the file. As an example, the 'install' target does not reference other targets but the same command as another target.
# 	I also run these on a windows desktop and Make for windows attempts to spawn a linux process with the linux API when you call a target from another target.
# 	To work around this, I write the command once and reference the actual command everywhere.

.PHONY: add_helm_repo unpack_operator unpack_operator_crds namespace crds elastic install uninstall template get_elastic_user_pass

# Helm Repo stuff
OP_CHARTVER := 2.12.1
REPO := elastic
REPOURL := https://helm.elastic.co

# Helm/K8S stuff
NAMESPACE := elastic-system
VALUES := -f values.yaml -f secrets.yaml

# Lets not accidentally deploy this anywhere else.
CTX := k3s-devlab

install_crds_cmd := helm upgrade elasticsearch charts/eck-operator-crds -i --history-max 4 --atomic --cleanup-on-fail --kube-context $(CTX) -n $(NAMESPACE)
install_cmd := helm secrets upgrade elasticsearch ./ $(VALUES) -i --history-max 4 --atomic --cleanup-on-fail --kube-context $(CTX) -n $(NAMESPACE)
ns_cmd := kubectl create namespace $(NAMESPACE) --context $(CTX)
repo_update_cmd := helm repo update

# Add helm.elastic.co helm repo as elastic.
add_helm_repo:
	helm repo add $(REPO) $(REPOURL)

# Will pull the eck-operator from repo and extract it into charts
unpack_operator:
	@$(repo_update_cmd)
	rm -rf charts/eck-operator
	helm pull $(REPO)/eck-operator --version $(OP_CHARTVER) --untar=true --untardir=charts

# Will pull the eck-operator-crds from repo and extract it into charts
unpack_operator_crds:
	@$(repo_update_cmd)
	rm -rf charts/eck-operator-crds
	helm pull $(REPO)/eck-operator-crds --version $(OP_CHARTVER) --untar=true --untardir=charts

namespace:
	@$(ns_cmd)

crds:
	@$(install_crds_cmd)

elastic:
	@$(install_cmd)

# One command to deploy them all.
install:
	-@$(ns_cmd)
	@$(install_crds_cmd)
	@$(install_cmd)

uninstall:
	helm uninstall elasticsearch --kube-context $(CTX) -n $(NAMESPACE)

# Used for generating and checking manifest files.
template:
	helm template --release-name --create-namespace $(NAMESPACE) $(VALUES) ./ -n $(NAMESPACE)

# Windows Users wont have base64decode. You will have to create a profile function with this name to do a similar job.
# function base64decode ($value) {[Text.Encoding]::Utf8.GetString([Convert]::FromBase64String($value))}
get_elastic_user_pass:
	kubectl get secret elastic-cluster-es-elastic-user -n elastic-system --context $(CTX) -o go-template='{{.data.elastic | base64decode}}'
