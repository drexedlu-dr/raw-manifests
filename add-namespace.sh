#!/bin/bash

# Script to add namespace: argocd to all Kubernetes namespaced resources
# while preserving cluster-wide resources

set -euo pipefail

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
OUTPUT_FILE="${2:-install-with-namespace.yaml}"
NAMESPACE="${3:-argocd}"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' not found!"
    echo "Usage: $0 [input_file] [output_file] [namespace]"
    echo "  input_file: YAML file containing Kubernetes resources (default: install.yaml)"
    echo "  output_file: Output file with namespace added (default: install-with-namespace.yaml)"
    echo "  namespace: Namespace to add to resources (default: argocd)"
    exit 1
fi

echo "Processing Kubernetes resources..."
echo "Input file: $INPUT_FILE"
echo "Output file: $OUTPUT_FILE"
echo "Target namespace: $NAMESPACE"

# Create a temporary file for processing
TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

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

# Process the YAML file using awk
awk -v namespace="$NAMESPACE" '
BEGIN {
    in_resource = 0
    current_kind = ""
    cluster_wide_resources["CustomResourceDefinition"] = 1
    cluster_wide_resources["ClusterRole"] = 1
    cluster_wide_resources["ClusterRoleBinding"] = 1
    cluster_wide_resources["PersistentVolume"] = 1
    cluster_wide_resources["StorageClass"] = 1
    cluster_wide_resources["Namespace"] = 1
    cluster_wide_resources["ValidatingAdmissionWebhook"] = 1
    cluster_wide_resources["MutatingAdmissionWebhook"] = 1
    cluster_wide_resources["PriorityClass"] = 1
    cluster_wide_resources["RuntimeClass"] = 1
    cluster_wide_resources["VolumeSnapshotClass"] = 1
    cluster_wide_resources["IngressClass"] = 1
    cluster_wide_resources["CSIDriver"] = 1
    cluster_wide_resources["CSINode"] = 1
    cluster_wide_resources["CSIStorageCapacity"] = 1
    namespace_added = 0
}

# Detect start of new resource
/^apiVersion:/ {
    in_resource = 1
    current_kind = ""
    namespace_added = 0
    print $0
    next
}

# Capture the kind
/^kind:/ && in_resource {
    current_kind = $2
    print $0
    next
}

# Process metadata section
/^metadata:/ && in_resource {
    print $0
    # For namespaced resources, add namespace after metadata line
    if (current_kind != "" && !(current_kind in cluster_wide_resources) && namespace_added == 0) {
        print "  namespace: " namespace
        namespace_added = 1
    }
    next
}

# Skip existing namespace lines in namespaced resources to avoid duplicates
/^  namespace:/ && in_resource && current_kind != "" && !(current_kind in cluster_wide_resources) {
    # Replace existing namespace with our target namespace
    print "  namespace: " namespace
    next
}

# Print all other lines as-is
{
    print $0
}
' "$INPUT_FILE" > "$TEMP_FILE"

# Move the temporary file to the output file
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "Processing completed!"
echo ""
echo "Summary:"

# Count the different resource types
echo "Resource types found in the file:"
grep "^kind:" "$INPUT_FILE" | sort | uniq -c | while read -r count kind_line; do
    kind=$(echo "$kind_line" | sed 's/kind: //')
    if is_cluster_wide_resource "$kind"; then
        printf "  %-25s %3d (cluster-wide - no namespace added)\n" "$kind:" "$count"
    else
        printf "  %-25s %3d (namespaced - namespace added)\n" "$kind:" "$count"
    fi
done

echo ""
echo "Verification - checking for resources with namespace '$NAMESPACE':"
namespace_count=$(grep -c "namespace: $NAMESPACE" "$OUTPUT_FILE" || echo "0")
echo "Found $namespace_count resources with namespace '$NAMESPACE'"

echo ""
echo "Done! Check the output file: $OUTPUT_FILE"