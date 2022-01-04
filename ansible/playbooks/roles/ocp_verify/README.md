ocp_verify
==========

This role will verify that a provisioned OCP cluster is ready to be setup for MAS.

In IBMCloud ROKS we have seen delays of over an hour before the Red Hat Operator catalog is ready to use.  This will cause attempts to install anything from that CatalogSource to fail as the timeouts built into those roles are designed to catch problems with an install, rather than a half-provisioned cluster that is not properly ready to use.


Role Variables
--------------
The role requires no variables itself, but depends on the `ocp_login` role, and as such inherits it's requirements.

- `cluster_name` Gives a name for the provisioning cluster
- `cluster_type` quickburn | roks

#### ROKS specific facts
- `ibmcloud_apikey` APIKey to be used by ibmcloud login comand

#### Fyre specific facts
- `username` Required when cluster type is quickburn
- `password` Required when cluster type is quickburn


Example Playbook
----------------

```yaml
- hosts: localhost
  vars:
    cluster_name: "{{ lookup('env', 'CLUSTER_NAME')}}"
    cluster_type: roks
    ibmcloud_apikey: "{{ lookup('env', 'IBMCLOUD_APIKEY') }}"
    ibmcloud_resourcegroup: "{{ lookup('env', 'IBMCLOUD_RESOURCEGROUP') | default('Default', true) }}"
  roles:
    - ocp_verify
```


License
-------

EPL-2.0
