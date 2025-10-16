#!/bin/bash

# Alternative script using yq for more robust YAML processing
# This script adds namespace: argocd to all Kubernetes namespaced resources

set -euo pipefail

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "Error: 'yq' is required but not installed."
    echo "Please install yq from: https://github.com/mikefarah/yq"
    echo ""
    echo "Installation options:"
    echo "  macOS: brew install yq"
    echo "  Linux: wget -qO- https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 | sudo tee /usr/local/bin/yq > /dev/null && sudo chmod +x /usr/local/bin/yq"
    exit 1
fi

# Define cluster-wide resource types that should NOT have namespace added
CLUSTER_WIDE_RESOURCES=(
    "CustomResourceDefinition"
    "ClusterRole"
    "ClusterRoleBinding"
    "PersistentVolume"
    "StorageClass"
    "Namespace"
    "ValidatingAdmissionWebhook"
    "MutatingAdmissionWebhook"
    "PriorityClass"
    "RuntimeClass"
    "VolumeSnapshotClass"
    "IngressClass"
    "CSIDriver"
    "CSINode"
    "CSIStorageCapacity"
)

# Input and output file paths
INPUT_FILE="${1:-install.yaml}"
OUTPUT_FILE="${2:-install-with-namespace-yq.yaml}"
NAMESPACE="${3:-argocd}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    echo "Usage: $0 [input_file] [output_file] [namespace]"
    echo "  input_file: YAML file containing Kubernetes resources (default: install.yaml)"
    echo "  output_file: Output file with namespace added (default: install-with-namespace-yq.yaml)"
    echo "  namespace: Namespace to add to resources (default: argocd)"
    exit 1
fi

echo "Processing Kubernetes resources using yq..."
echo "Input file: $INPUT_FILE"
echo "Output file: $OUTPUT_FILE"
echo "Target namespace: $NAMESPACE"

# Function to check if a resource type is cluster-wide
is_cluster_wide_resource() {
    local kind="$1"
    for cluster_resource in "${CLUSTER_WIDE_RESOURCES[@]}"; do
        if [ "$kind" = "$cluster_resource" ]; then
            return 0
        fi
    done
    return 1
}

# Create a temporary file for processing
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

# Split the multi-document YAML and process each document
yq eval-all 'select(.)' "$INPUT_FILE" | yq eval-all --output-format=yaml '. as $doc | 
    if ($doc.kind and ($doc.kind | test("^(CustomResourceDefinition|ClusterRole|ClusterRoleBinding|PersistentVolume|StorageClass|Namespace|ValidatingAdmissionWebhook|MutatingAdmissionWebhook|PriorityClass|RuntimeClass|VolumeSnapshotClass|IngressClass|CSIDriver|CSINode|CSIStorageCapacity)$"))) then
        $doc
    else
        $doc | .metadata.namespace = "'"$NAMESPACE"'"
    end' > "$TEMP_FILE"

# Insert the Namespace resource at the beginning of the output file
cp argocd-namespace.yaml "$OUTPUT_FILE"
cat "$TEMP_FILE" >> "$OUTPUT_FILE"

echo "Processing completed!"
echo ""
echo "Summary:"

# Count the different resource types
echo "Resource types found in the file:"
yq eval '.kind' "$INPUT_FILE" | sort | uniq -c | while read -r count kind; do
    if [ "$kind" != "null" ] && [ "$kind" != "---" ]; then
        if is_cluster_wide_resource "$kind"; then
            printf "  %-25s %3d (cluster-wide - no namespace added)\n" "$kind:" "$count"
        else
            printf "  %-25s %3d (namespaced - namespace added)\n" "$kind:" "$count"
        fi
    fi
done

echo ""
echo "Verification - checking for resources with namespace '$NAMESPACE':"
namespace_count=$(yq eval '.metadata.namespace' "$OUTPUT_FILE" | grep -c "^$NAMESPACE$" || echo "0")
echo "Found $namespace_count resources with namespace '$NAMESPACE'"

echo ""
echo "Done! Check the output file: $OUTPUT_FILE"