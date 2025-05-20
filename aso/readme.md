

Here's your env file (`aso/cluster.env`) with all the variables from your ConfigMap, ready for use with `envsubst` or `sed` for template replacement.

If you want a one-liner to replace variables in your template:
```sh
envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```
or with sed (for ${VAR} style):
```sh
set -a; source aso/cluster.env; set +a
envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```

Let me know if you want a script for batch replacement or more automation.
