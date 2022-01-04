ocp_login
=========

This role provides support to login to a cluster using the `oc cli`


Role Variables
--------------

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
    - ocp_login
```

License
-------

EPL-2.0
