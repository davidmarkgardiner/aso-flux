

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

If you use `envsubst`, you do **not** need to source the env file—just run:
```sh
envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```
as long as you export the variables in your current shell, or use `envsubst` with variables set inline.

If you want to use the variables in your shell (e.g., for `sed` or other scripts), you should source the env file:
```sh
set -a
source aso/cluster.env
set +a
```
This exports all variables in the file to your environment.

**Summary:**  
- For `envsubst`, you can either export variables or source the file.
- For `sed` or shell scripts that use `$VAR`, you must source the env file so the variables are available.

If you want a pure one-liner for `envsubst`:
```sh
set -a; source aso/cluster.env; set +a; envsubst < aso/templated-cluster.yaml > rendered-cluster.yaml
```

If you just want to replace in-place with `sed`, you must source the env file first.

