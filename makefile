# Define variables for ArgoCD configuration
ARGOCD_NAMESPACE := argocd
ARGOCD_APP_NAME := guestbook
ARGOCD_SERVER := localhost:8080

.PHONY: setup-argocd deploy-app create-app

setup-argocd:

    ifeq ($(shell kubectl get namespace $(ARGOCD_NAMESPACE) 2>/dev/null),)
        kubectl create namespace $(ARGOCD_NAMESPACE)
    endif

	# Install ArgoCD using manifest 
	# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	
	kubectl apply -n $(ARGOCD_NAMESPACE) -f crds/

	# Wait for ArgoCD pods to be ready
	kubectl wait --for=condition=ready pods -n $(ARGOCD_NAMESPACE) --timeout=300s -l app.kubernetes.io/name=argocd-server

port-forward:

	@echo "Below is the user and password to login"
	@echo "user: admin"
	@echo "password below"
	argocd admin initial-password -n $(ARGOCD_NAMESPACE)

	# Open the ArgoCD web UI in your default browser
	@echo "Click on the link below to open ArgoCD web UI" 
	@echo "http://$(ARGOCD_SERVER)"

	# Port-forward the ArgoCD server for local access
	kubectl port-forward -n $(ARGOCD_NAMESPACE) svc/argocd-server 8080:443

argocd-login:

	# Log in to the ArgoCD CLI
	argocd login $(ARGOCD_SERVER)

create-app:
	kubectl config set-context --current --namespace=argocd

	kubectl apply -f repo-secret.yaml -n $(ARGOCD_NAMESPACE)
	kubectl apply -f app.yaml -n $(ARGOCD_NAMESPACE)

	@echo "By default the created app is snyced. But to be sure you can execute 'make argo-app-sync'"

argo-app-sync:

	# Sync the application to deploy it
	argocd app sync $(ARGOCD_APP_NAME)

	# Wait for the application to be synchronized and healthy
	argocd app wait $(ARGOCD_APP_NAME)

	# Open the ArgoCD web UI in your default browser
	@echo "Click on the link below to open ArgoCD web UI" 

argo-app-status:
	argocd app get guestbook-test


.PHONY: clean

clean:
	# Delete the ArgoCD application
	argocd app delete $(ARGOCD_APP_NAME)

	# Uninstall ArgoCD using Helm
	helm uninstall argocd -n $(ARGOCD_NAMESPACE)

	# Delete the ArgoCD namespace
	kubectl delete namespace $(ARGOCD_NAMESPACE)

	# Kill the port-forwarding process
	pkill -f 'kubectl port-forward -n $(ARGOCD_NAMESPACE) svc/argocd-server 8080:443'

