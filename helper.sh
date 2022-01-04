#!/bin/bash

# Helper functions
log() {
  echo "$(date +%a-%d-%b-%Y-%H-%M-%S) $1"
}

# Retrieve MAS CA certificate
retrieve_mas_ca_cert() {
  uniqstr=$1
  filepath=$2
  # Wait until the secret is available
  found="false"
  counter=0
  while [[ $found == "false" ]] && [[ $counter < 20 ]]; do
    oc get secret mas-${uniqstr}-cert-public-ca --kubeconfig ${KUBE_CONFIG} -n cert-manager
    if [[ $? -eq 1 ]]; then
      log "OCP secret mas-${uniqstr}-cert-public-ca not found, waiting ..."
      sleep 30
      counter=$((counter+1))
      continue
    else
      log "OCP secret mas-${uniqstr}-cert-public-ca found"
      found="true"
    fi
    oc get secret mas-${uniqstr}-cert-public-ca --kubeconfig ${KUBE_CONFIG} -n cert-manager -o yaml | grep ca.crt | cut -d ':' -f 2 | tr -d " ,\"" | base64 -d > $filepath
  done
}

# Get credentials for MAS
get_mas_creds() {
  uniqstr=$1
  # Wait until the secret is available
  found="false"
  counter=0
  while [[ $found == "false" ]] && [[ $counter < 20 ]]; do
    oc get secret mas-${uniqstr}-credentials-superuser --kubeconfig ${KUBE_CONFIG} -n mas-mas-${uniqstr}-core
    if [[ $? -eq 1 ]]; then
      log "OCP secret mas-${uniqstr}-credentials-superuser not found, waiting ..."
      sleep 30
      counter=$((counter+1))
      continue
    else
      log "OCP secret mas-${uniqstr}-credentials-superuser found"
      found="true"
    fi
    username=$(oc get secret mas-${uniqstr}-credentials-superuser --kubeconfig ${KUBE_CONFIG} -n mas-mas-${uniqstr}-core -o json | grep "\"username\"" | cut -d ':' -f 2 | tr -d " ,\"" | base64 -d)
    password=$(oc get secret mas-${uniqstr}-credentials-superuser --kubeconfig ${KUBE_CONFIG} -n mas-mas-${uniqstr}-core -o json | grep "\"password\"" | cut -d ':' -f 2 | tr -d " ,\"" | base64 -d)
  done

  if [[ $found == "false" ]]; then
    export MAS_USER=null
    export MAS_PASSWORD=null
    log "MAS username and password not found"
  else
    export MAS_USER=$username
    export MAS_PASSWORD=$password
    log "MAS username and password found"
  fi
}