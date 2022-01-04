cp4d_db2wh
==========

TODO: Add intro

Role Variables
--------------

TODO: Finish documentation


Example Playbook
----------------

```yaml
- hosts: localhost
  any_errors_fatal: true
  vars:
    # Configuration for the Db2 cluster
    db2wh_version: 11.5.5.1-cn3
    db2wh_username: db2inst1
    db2wh_instance_id: db2wh-db01
    db2wh_dbname: BLUDB

    # Create the MAS JdbcCfg & Secret resource definitions
    mas_instance_id: "{{ lookup('env', 'MAS_INSTANCE_ID') }}"
    mas_config_dir: "{{ lookup('env', 'MAS_CONFIG_DIR') }}"
  roles:
    - ibm.mas_devops.cp4d_db2wh
```

License
-------

EPL-2.0
