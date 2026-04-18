#!/system/bin/sh
############################################
# Test Script for Per-Module Mount Modes
# This script tests the module mode parsing logic
############################################

TEST_JSON='{"ModuleA":"overlayfs","ModuleB":"magic","ModuleC":"ignore"}'

echo "=== Testing Module Mode Parsing ==="
echo ""
echo "Test JSON: $TEST_JSON"
echo ""

# Test get_module_mount_mode function
get_module_mode() {
    local module_name="$1"
    local module_modes_json="$2"
    
    mode=$(echo "$module_modes_json" | grep -o "\"$module_name\":\"[^\"]*\"" 2>/dev/null | head -1)
    if [ -n "$mode" ]; then
        echo "$mode" | sed 's/.*":"//' | tr -d '"'
    else
        echo "global"
    fi
}

# Test each module
for mod in ModuleA ModuleB ModuleC ModuleD; do
    mode=$(get_module_mode "$mod" "$TEST_JSON")
    echo "Module: $mod -> Mode: $mode"
done

echo ""
echo "=== Expected Results ==="
echo "ModuleA -> overlayfs"
echo "ModuleB -> magic"
echo "ModuleC -> ignore"
echo "ModuleD -> global (fallback)"

echo ""
echo "=== Test Complete ==="
