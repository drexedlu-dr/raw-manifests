# ArgoCD Manifests

A place holder for ArgoCD manifests for a plain installation of ArgoCD.



## Update ArgoCD manifests

Update the version and run the commands
```
export ARGOCD_VERSION=v3.1.8

curl http://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}}$/manifests/install.yaml -v

rm -f install-with-namespace.yaml

./add-namespace.sh

git add .
git commit -m "Argocd ${ARGOCD_VERSION}"
git tag ARGOCD-${ARGOCD_VERSION}
git push --tags
```

This repository contains bash scripts to add a namespace to Kubernetes resources while preserving cluster-wide resources.

## Files

- `add-namespace.sh` - Main script using awk (no external dependencies)
- `add-namespace-yq.sh` - Alternative script using yq for robust YAML processing
- `test-scripts.sh` - Test script to verify functionality
- `install.yaml` - Original ArgoCD installation manifest

## Usage

### Basic Usage

```bash
# Using the awk-based script (recommended for most cases)
./add-namespace.sh install.yaml install-with-namespace.yaml argocd

# Using the yq-based script (requires yq to be installed)
./add-namespace-yq.sh install.yaml install-with-namespace.yaml argocd
```

### Parameters

All scripts accept three optional parameters:

1. **Input file** (default: `install.yaml`) - The original Kubernetes YAML file
2. **Output file** (default: varies by script) - Where to save the modified YAML
3. **Namespace** (default: `argocd`) - The namespace to add to resources

### Examples

```bash
# Use default values (install.yaml -> install-with-namespace.yaml, namespace: argocd)
./add-namespace.sh

# Specify custom input and output files
./add-namespace.sh my-app.yaml my-app-namespaced.yaml production

# Only specify namespace, use default files
./add-namespace.sh "" "" development
```

## What the Scripts Do

### Resources That Get Namespace Added (Namespaced Resources)

- ServiceAccount
- Role
- RoleBinding
- ConfigMap
- Secret
- Service
- Deployment
- StatefulSet
- DaemonSet
- Job
- CronJob
- Pod
- ReplicaSet
- Ingress
- NetworkPolicy
- PersistentVolumeClaim

### Resources That Are NOT Modified (Cluster-wide Resources)

- CustomResourceDefinition
- ClusterRole
- ClusterRoleBinding
- PersistentVolume
- StorageClass
- Namespace
- ValidatingAdmissionWebhook
- MutatingAdmissionWebhook
- PriorityClass
- RuntimeClass
- VolumeSnapshotClass
- IngressClass
- CSIDriver
- CSINode
- CSIStorageCapacity

## Script Details

### `add-namespace.sh` (AWK-based)

**Advantages:**
- No external dependencies (uses standard unix tools)
- Fast processing
- Works on any system with bash and awk

**How it works:**
- Uses awk to parse the YAML file
- Identifies resource types by their `kind:` field
- Adds `namespace: <target-namespace>` under the `metadata:` section for namespaced resources
- Replaces existing namespace declarations for namespaced resources
- Leaves cluster-wide resources unchanged

### `add-namespace-yq.sh` (YQ-based)

**Advantages:**
- More robust YAML parsing
- Better handling of complex YAML structures
- Preserves YAML formatting and comments better

**Requirements:**
- Requires `yq` (YAML processor) to be installed
- Installation: `brew install yq` (macOS) or see https://github.com/mikefarah/yq

**How it works:**
- Uses yq to properly parse and modify YAML documents
- Processes each document in the multi-document YAML file
- Adds namespace to metadata for non-cluster-wide resources

## Testing

Run the test script to verify functionality:

```bash
chmod +x test-scripts.sh
./test-scripts.sh
```

This will:
1. Create a test YAML file with mixed resource types
2. Run both scripts on the test file
3. Display the results for comparison

## Installation

1. Make the scripts executable:
```bash
chmod +x add-namespace.sh add-namespace-yq.sh test-scripts.sh
```

2. For the yq-based script, install yq:
```bash
# macOS
brew install yq

# Linux
wget -qO- https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 | sudo tee /usr/local/bin/yq > /dev/null && sudo chmod +x /usr/local/bin/yq
```

## Example Output

When running the script on the ArgoCD installation manifest, you'll see output like:

```
Processing Kubernetes resources...
Input file: install.yaml
Output file: install-with-namespace.yaml
Target namespace: argocd

Processing completed!

Summary:
Resource types found in the file:
  CustomResourceDefinition:    3 (cluster-wide - no namespace added)
  ServiceAccount:              7 (namespaced - namespace added)
  Role:                        6 (namespaced - namespace added)
  ClusterRole:                 3 (cluster-wide - no namespace added)
  RoleBinding:                 6 (namespaced - namespace added)
  ClusterRoleBinding:          3 (cluster-wide - no namespace added)
  ConfigMap:                   7 (namespaced - namespace added)
  Secret:                      2 (namespaced - namespace added)
  Service:                     8 (namespaced - namespace added)
  Deployment:                  6 (namespaced - namespace added)
  StatefulSet:                 1 (namespaced - namespace added)
  NetworkPolicy:               7 (namespaced - namespace added)

Verification - checking for resources with namespace 'argocd':
Found 50 resources with namespace 'argocd'

Done! Check the output file: install-with-namespace.yaml
```

## Troubleshooting

### Common Issues

1. **Permission denied**: Make sure the script is executable (`chmod +x script-name.sh`)

2. **yq not found**: Install yq if using the yq-based script

3. **File not found**: Ensure the input file path is correct

4. **Unexpected output**: The awk-based script assumes standard YAML formatting. For complex YAML files, use the yq-based script.

### Validation

After running the script, you can validate the output:

```bash
# Check that namespaced resources have the namespace
grep -A5 "^kind: ServiceAccount" install-with-namespace.yaml

# Verify cluster-wide resources don't have namespace
grep -A10 "^kind: CustomResourceDefinition" install-with-namespace.yaml
```

## Contributing

Feel free to modify the scripts for your specific needs. The cluster-wide resource list can be updated in the `CLUSTER_WIDE_RESOURCES` array at the top of each script.